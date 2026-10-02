const {
  normalizeCi,
  splitNombreApellido,
  parseFlexibleDate,
  normalizeEstatus,
  getField,
} = require('./normalize');
const { parseCsvFile } = require('./parseCsv');
const {
  findPersonaByCi,
  insertPersona,
  updatePersona,
} = require('../../lib/crudFactory');

async function upsertObservacion(client, entidad, entidadId, texto) {
  if (!texto || !String(texto).trim()) return;
  const t = String(texto).trim();
  const existing = await client.query(
    `SELECT observacion_id FROM observaciones
     WHERE entidad = $1 AND entidad_id = $2 AND origen = 'importacion' AND texto = $3
     LIMIT 1`,
    [entidad, entidadId, t]
  );
  if (existing.rowCount > 0) return;
  await client.query(
    `INSERT INTO observaciones (entidad, entidad_id, texto, origen)
     VALUES ($1,$2,$3,'importacion')`,
    [entidad, entidadId, t]
  );
}

async function findPersonaSinCi(client, nombre, apellido) {
  const r = await client.query(
    `SELECT * FROM personas
     WHERE COALESCE(ci, '') = ''
       AND lower(btrim(nombre)) = lower(btrim($1))
       AND lower(btrim(apellido)) = lower(btrim($2))
     LIMIT 1`,
    [nombre, apellido]
  );
  return r.rows[0] || null;
}

/**
 * config:
 * - modulo, entidad, table, idColumn
 * - institutoColumn: 'colegio' | 'instituto' | 'institucion'
 * - extraFields: fn(row, ctx) => object of extra columns
 * - defaultTipoActividad / matchTipoActividad: for otros/postgrado
 * - hasCarrera, hasExpediente
 */
async function importEstudiantes(pool, filePath, config, { dryRun = false, rejected = [] } = {}) {
  const rows = parseCsvFile(filePath, {
    headerHints: ['estatus', 'nombre'],
  });

  let created = 0;
  let updated = 0;
  let skipped = 0;

  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    const line = i + 2;

    const nombreFull = getField(row, ['Nombre y Apellido', 'Participante']);
    const ciRaw = getField(row, ['Cédula de Identidad', 'Cedula de Identidad', 'CI', 'Cédula']);
    const ci = normalizeCi(ciRaw);

    const estatusRaw = getField(row, ['Estatus']);
    // Detect clearly misaligned rows (estatus looks like a date or address)
    if (estatusRaw && /^\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}$/.test(estatusRaw.trim())) {
      rejected.push({
        modulo: config.modulo,
        linea: line,
        motivo: 'Fila desalineada (estatus parece fecha)',
        raw: JSON.stringify(row).slice(0, 500),
      });
      skipped++;
      continue;
    }

    if (!nombreFull) {
      rejected.push({
        modulo: config.modulo,
        linea: line,
        motivo: 'Sin nombre',
        ci,
      });
      skipped++;
      continue;
    }

    const sinCedula = !ci;
    if (sinCedula) {
      rejected.push({
        modulo: config.modulo,
        linea: line,
        motivo: 'Importada sin cédula',
        nombre: nombreFull,
        raw: JSON.stringify(row).slice(0, 400),
      });
    }

    const { estatus, original: estatusOriginal } = normalizeEstatus(estatusRaw);
    const { nombre, apellido } = splitNombreApellido(nombreFull);
    const email = getField(row, ['Email']);
    const telefono = getField(row, ['Teléfono', 'Telefono']);
    const induccion = parseFlexibleDate(getField(row, ['Fecha de Inducción', 'Fecha de Induccion']));
    const instituto = getField(row, [
      'Colegio / Instituto',
      'Universidad / Instituto',
      'Instituto',
      'Colegio',
    ]);
    const carrera = getField(row, ['Carrera']);
    const inicio = parseFlexibleDate(getField(row, ['Fecha de Inicio']));
    const culminacion = parseFlexibleDate(getField(row, ['Fecha de Culminación', 'Fecha de Culminacion']));
    const anioRaw = getField(row, ['Año', 'Ano', 'Año ']);
    const anioParsed = anioRaw ? parseInt(String(anioRaw).replace(/\D/g, ''), 10) : null;
    const anioSafe = Number.isNaN(anioParsed) ? null : anioParsed;
    const observaciones = getField(row, ['Observaciones']);
    const otro = getField(row, ['Otro']);

    if (dryRun) {
      created++;
      continue;
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      let persona = ci
        ? await findPersonaByCi(client, ci)
        : await findPersonaSinCi(client, nombre, apellido);

      const personaData = {
        ci: ci || null,
        nombre,
        apellido,
        telefono,
        email,
        fecha_induccion: induccion.date,
      };

      if (persona) {
        persona = await updatePersona(client, persona.persona_id, personaData);
      } else {
        persona = await insertPersona(client, personaData);
      }

      const extras = config.extraFields
        ? config.extraFields(row, {
            instituto,
            carrera,
            anio: anioSafe,
            estatus,
            inicio,
            culminacion,
            otro,
          })
        : {};

      let matchParams;
      let matchSql;
      if (config.matchByPersona) {
        matchParams = [persona.persona_id];
        matchSql = `SELECT ${config.idColumn} AS id, fecha_inicio::text AS fecha_inicio
           FROM ${config.table} WHERE persona_id = $1`;
      } else {
        matchParams = [persona.persona_id, anioSafe, inicio.date];
        matchSql = `SELECT ${config.idColumn} AS id FROM ${config.table}
           WHERE persona_id = $1
             AND anio IS NOT DISTINCT FROM $2
             AND fecha_inicio IS NOT DISTINCT FROM $3`;
        if (config.matchTipoActividad) {
          matchParams.push(config.matchTipoActividad);
          matchSql += ` AND tipo_actividad = $${matchParams.length}`;
        }
      }
      matchSql += ` ORDER BY ${config.idColumn} LIMIT 1`;

      const existing = await client.query(matchSql, matchParams);

      let entityId;
      if (existing.rowCount > 0) {
        entityId = existing.rows[0].id;
        const existingInicio = existing.rows[0].fecha_inicio;
        const isOlder =
          config.matchByPersona &&
          existingInicio &&
          inicio.date &&
          inicio.date < existingInicio;
        const setParts = [];
        const vals = [];
        const fields = {
          ...extras,
          anio: anioSafe,
          estatus,
          fecha_inicio: inicio.date,
          fecha_culminacion: culminacion.date,
        };
        if (config.institutoColumn) {
          fields[config.institutoColumn] = instituto;
        }
        if (config.hasCarrera) {
          fields.carrera = carrera;
        }
        if (config.hasExpediente) {
          fields.expediente = otro;
        }
        for (const [k, v] of Object.entries(fields)) {
          if (v !== undefined) {
            vals.push(v);
            setParts.push(isOlder ? `${k} = COALESCE(${k}, $${vals.length})` : `${k} = $${vals.length}`);
          }
        }
        setParts.push('activo = TRUE');
        vals.push(entityId);
        await client.query(
          `UPDATE ${config.table} SET ${setParts.join(', ')} WHERE ${config.idColumn} = $${vals.length}`,
          vals
        );
        updated++;
      } else {
        const fields = {
          persona_id: persona.persona_id,
          anio: anioSafe,
          estatus,
          fecha_inicio: inicio.date,
          fecha_culminacion: culminacion.date,
          activo: true,
          ...extras,
        };
        if (config.institutoColumn) fields[config.institutoColumn] = instituto;
        if (config.hasCarrera) fields.carrera = carrera;
        if (config.hasExpediente) fields.expediente = otro;
        if (config.defaultTipoActividad) {
          fields.tipo_actividad = config.defaultTipoActividad;
        }

        const cols = Object.keys(fields);
        const vals = Object.values(fields);
        const placeholders = cols.map((_, idx) => `$${idx + 1}`).join(', ');
        const ins = await client.query(
          `INSERT INTO ${config.table} (${cols.join(', ')})
           VALUES (${placeholders})
           RETURNING ${config.idColumn} AS id`,
          vals
        );
        entityId = ins.rows[0].id;
        created++;
      }

      await upsertObservacion(client, config.entidad, entityId, observaciones);
      if (estatusOriginal && estatus && estatusOriginal !== estatus) {
        await upsertObservacion(
          client,
          config.entidad,
          entityId,
          `Estatus original en Excel: ${estatusOriginal}`
        );
      }

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      rejected.push({
        modulo: config.modulo,
        linea: line,
        motivo: err.message,
        nombre: nombreFull,
        ci,
      });
      skipped++;
    } finally {
      client.release();
    }
  }

  return { modulo: config.modulo, total: rows.length, created, updated, skipped };
}

const MODULE_CONFIGS = {
  labor_social: {
    modulo: 'labor_social',
    entidad: 'labor_social',
    table: 'labor_social',
    idColumn: 'labor_social_id',
    institutoColumn: 'colegio',
    hasCarrera: true,
    hasExpediente: true,
    matchByPersona: true,
    extraFields: () => ({ nivel: null }),
  },
  servicio_comunitario: {
    modulo: 'servicio_comunitario',
    entidad: 'servicio_comunitario',
    table: 'servicio_comunitario_universitario',
    idColumn: 'servicio_comunitario_id',
    institutoColumn: 'instituto',
    hasCarrera: true,
    extraFields: () => ({ proyecto: null }),
  },
  pasantia: {
    modulo: 'pasantia',
    entidad: 'pasantia',
    table: 'pasantia_tesis_proyecto',
    idColumn: 'pasantia_tesis_proyecto_id',
    institutoColumn: 'instituto',
    hasCarrera: true,
    extraFields: (_row, { carrera }) => ({
      tipo: 'pasantia',
      tutor_academico: null,
      tutor_institucional: null,
      carrera,
    }),
  },
  postgrado: {
    modulo: 'postgrado',
    entidad: 'otros',
    table: 'otros',
    idColumn: 'otros_id',
    institutoColumn: 'institucion',
    hasCarrera: true,
    defaultTipoActividad: 'Postgrado',
    matchTipoActividad: 'Postgrado',
    extraFields: () => ({}),
  },
};

module.exports = { importEstudiantes, MODULE_CONFIGS };
