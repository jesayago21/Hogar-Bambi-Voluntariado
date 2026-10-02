const path = require('path');
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

async function upsertObservacion(client, entidad, entidadId, texto, dryRun) {
  if (!texto || !String(texto).trim()) return;
  if (dryRun) return;
  const existing = await client.query(
    `SELECT observacion_id FROM observaciones
     WHERE entidad = $1 AND entidad_id = $2 AND origen = 'importacion' AND texto = $3
     LIMIT 1`,
    [entidad, entidadId, String(texto).trim()]
  );
  if (existing.rowCount > 0) return;
  await client.query(
    `INSERT INTO observaciones (entidad, entidad_id, texto, origen)
     VALUES ($1,$2,$3,'importacion')`,
    [entidad, entidadId, String(texto).trim()]
  );
}

async function importVoluntarios(pool, filePath, { dryRun = false, rejected = [] } = {}) {
  const rows = parseCsvFile(filePath, {
    headerHints: ['estatus', 'participante', 'ci'],
  });

  let created = 0;
  let updated = 0;
  let skipped = 0;

  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    const line = i + 2;

    const participante = getField(row, ['Participante', 'Nombre y Apellido']);
    const ciRaw = getField(row, ['CI', 'Cédula de Identidad', 'Cedula']);
    const ci = normalizeCi(ciRaw);

    // Skip garbage rows (misaligned excel)
    const estatusRaw = getField(row, ['Estatus']);
    const { estatus, original: estatusOriginal } = normalizeEstatus(estatusRaw);
    if (!estatus || !['Activo', 'Inactivo'].includes(estatus)) {
      if (!participante || !ci) {
        rejected.push({
          modulo: 'voluntarios',
          linea: line,
          motivo: 'Fila inválida o desalineada (estatus/CI)',
          raw: JSON.stringify(row).slice(0, 500),
        });
        skipped++;
        continue;
      }
    }

    if (!ci && !participante) {
      rejected.push({
        modulo: 'voluntarios',
        linea: line,
        motivo: 'Sin CI ni nombre',
        raw: JSON.stringify(row).slice(0, 500),
      });
      skipped++;
      continue;
    }

    if (!ci) {
      rejected.push({
        modulo: 'voluntarios',
        linea: line,
        motivo: 'Sin cédula',
        nombre: participante,
        raw: JSON.stringify(row).slice(0, 500),
      });
      skipped++;
      continue;
    }

    const { nombre, apellido } = splitNombreApellido(participante);
    const telefono = getField(row, ['Telefono de Contacto', 'Teléfono', 'Telefono']);
    const email = getField(row, ['Email']);
    const residencia = getField(row, ['Zona donde vive']);
    const nacimiento = parseFlexibleDate(getField(row, ['Fecha Nacimiento']));
    const induccion = parseFlexibleDate(getField(row, ['Inducción', 'Induccion']));
    const inicio = parseFlexibleDate(getField(row, ['Fecha de Inicio']));
    const perfil = getField(row, ['Perfil']);
    const lugar = getField(row, ['Lugar de Trabajo y Cargo']);
    const actividad = getField(row, ['Actividad']);
    const asistenciasRaw = getField(row, ['Asistencias']);
    const observaciones = getField(row, ['Observaciones']);
    const asistencias = asistenciasRaw ? parseInt(String(asistenciasRaw).replace(/\D/g, ''), 10) : null;

    const finalEstatus = estatus === 'Activo' || estatus === 'Inactivo' ? estatus : 'Inactivo';

    if (dryRun) {
      created++;
      continue;
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      let persona = await findPersonaByCi(client, ci);
      const personaData = {
        ci,
        nombre,
        apellido,
        telefono,
        email,
        fecha_nacimiento: nacimiento.date,
        residencia,
        fecha_induccion: induccion.date,
      };

      if (persona) {
        persona = await updatePersona(client, persona.persona_id, personaData);
        const existingVol = await client.query(
          `SELECT voluntario_id FROM voluntarios WHERE persona_id = $1 ORDER BY voluntario_id LIMIT 1`,
          [persona.persona_id]
        );
        if (existingVol.rowCount > 0) {
          const vid = existingVol.rows[0].voluntario_id;
          await client.query(
            `UPDATE voluntarios SET
              fecha_inicio = COALESCE($1, fecha_inicio),
              estatus = $2,
              profesion_oficio = COALESCE($3, profesion_oficio),
              lugar_trabajo = COALESCE($4, lugar_trabajo),
              asistencias = COALESCE($5, asistencias),
              actividad = COALESCE($6, actividad),
              activo = TRUE
             WHERE voluntario_id = $7`,
            [
              inicio.date,
              finalEstatus,
              perfil,
              lugar,
              Number.isNaN(asistencias) ? null : asistencias,
              actividad,
              vid,
            ]
          );
          await upsertObservacion(client, 'voluntario', vid, observaciones, false);
          if (estatusOriginal && estatusOriginal !== finalEstatus) {
            await upsertObservacion(
              client,
              'voluntario',
              vid,
              `Estatus original en Excel: ${estatusOriginal}`,
              false
            );
          }
          updated++;
        } else {
          const ins = await client.query(
            `INSERT INTO voluntarios
              (persona_id, fecha_inicio, estatus, profesion_oficio, lugar_trabajo, asistencias, actividad, activo)
             VALUES ($1,$2,$3,$4,$5,$6,$7,TRUE)
             RETURNING voluntario_id`,
            [
              persona.persona_id,
              inicio.date,
              finalEstatus,
              perfil,
              lugar,
              Number.isNaN(asistencias) ? null : asistencias,
              actividad,
            ]
          );
          const vid = ins.rows[0].voluntario_id;
          await upsertObservacion(client, 'voluntario', vid, observaciones, false);
          created++;
        }
      } else {
        persona = await insertPersona(client, personaData);
        const ins = await client.query(
          `INSERT INTO voluntarios
            (persona_id, fecha_inicio, estatus, profesion_oficio, lugar_trabajo, asistencias, actividad, activo)
           VALUES ($1,$2,$3,$4,$5,$6,$7,TRUE)
           RETURNING voluntario_id`,
          [
            persona.persona_id,
            inicio.date,
            finalEstatus,
            perfil,
            lugar,
            Number.isNaN(asistencias) ? null : asistencias,
            actividad,
          ]
        );
        const vid = ins.rows[0].voluntario_id;
        await upsertObservacion(client, 'voluntario', vid, observaciones, false);
        created++;
      }

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      rejected.push({
        modulo: 'voluntarios',
        linea: line,
        motivo: err.message,
        nombre: participante,
        ci,
      });
      skipped++;
    } finally {
      client.release();
    }
  }

  return { modulo: 'voluntarios', total: rows.length, created, updated, skipped };
}

module.exports = { importVoluntarios };
