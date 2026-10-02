const ExcelJS = require('exceljs');
const {
  normalizeCi,
  normalizeEstatus,
  normalizeHeader,
} = require('./normalize');
const { coerceColumn, optionalString } = require('./validate');
const {
  findPersonaByCi,
  insertPersona,
  updatePersona,
} = require('./crudFactory');

function cellToString(value) {
  if (value === undefined || value === null) return '';
  if (value instanceof Date) {
    const y = value.getFullYear();
    const m = String(value.getMonth() + 1).padStart(2, '0');
    const d = String(value.getDate()).padStart(2, '0');
    return `${d}/${m}/${y}`;
  }
  if (typeof value === 'object' && value.text !== undefined) {
    return String(value.text).trim();
  }
  if (typeof value === 'object' && value.result !== undefined) {
    return cellToString(value.result);
  }
  return String(value).trim();
}

function isRowEmpty(values) {
  return values.every((v) => !cellToString(v));
}

function buildHeaderMap(headerRow, schema) {
  const map = {};
  const usedKeys = new Set();

  headerRow.eachCell({ includeEmpty: true }, (cell, colNumber) => {
    const raw = cellToString(cell.value);
    if (!raw) return;
    const norm = normalizeHeader(raw);

    let matched = schema.columns.find((c) => normalizeHeader(c.header) === norm);
    if (!matched) {
      matched = schema.columns.find((c) => {
        const h = normalizeHeader(c.header);
        return norm.includes(h) || h.includes(norm);
      });
    }
    if (matched && !usedKeys.has(matched.key)) {
      map[colNumber] = matched.key;
      usedKeys.add(matched.key);
    }
  });

  return map;
}

async function buildTemplate(schema) {
  const wb = new ExcelJS.Workbook();
  wb.creator = 'Voluntariado Hogar Bambi';

  const ws = wb.addWorksheet('Plantilla', {
    views: [{ state: 'frozen', ySplit: 1 }],
  });

  schema.columns.forEach((col, idx) => {
    const letter = ws.getColumn(idx + 1).letter;
    const cell = ws.getCell(1, idx + 1);
    cell.value = col.header;
    cell.font = { bold: true };
    cell.alignment = { vertical: 'middle', wrapText: true };
    ws.getColumn(idx + 1).width = col.width || 16;

    if (col.options && col.options.length) {
      const list = `"${col.options.join(',')}"`;
      for (let row = 2; row <= 500; row++) {
        ws.getCell(`${letter}${row}`).dataValidation = {
          type: 'list',
          allowBlank: true,
          formulae: [list],
          showErrorMessage: true,
          errorTitle: 'Estatus inválido',
          error: `Use uno de: ${col.options.join(', ')}`,
        };
      }
    }
  });

  const help = wb.addWorksheet('Instrucciones');
  help.getColumn(1).width = 90;
  const matchCols = schema.matchColumns || [];
  const dupRule = schema.keepLatest
    ? '• Un solo registro por cédula. Si la cédula ya existe, se actualiza con la fila de Inicio más reciente; una fila con Inicio más antiguo solo completa los campos vacíos.'
    : matchCols.length === 0
      ? '• Si la cédula ya existe en este módulo, se actualizarán los datos (un registro por persona).'
      : '• Una misma cédula puede repetirse en varias filas: cada combinación distinta de Año y Fecha de inicio crea un registro aparte; si coinciden, se actualiza ese registro (incluido el Estatus si cambió).';

  const lines = [
    `Plantilla de importación — ${schema.moduleName}`,
    '',
    'Reglas:',
    '• No cambie los encabezados de la hoja Plantilla.',
    '• Cédula es obligatoria en cada fila.',
    '• Nombre es obligatorio si la persona es nueva.',
    '• Fechas en formato DD/MM/AAAA (ejemplo: 15/03/2024).',
    dupRule,
    '• Las celdas vacías no borran datos existentes al actualizar.',
    '• Estatus: use la lista desplegable cuando esté disponible.',
    '• Observaciones: se AGREGAN al historial del registro; no reemplazan ni borran las anteriores.',
    '',
    'Columnas:',
    ...schema.columns.map((c) => {
      const req = c.required ? ' (obligatorio)' : '';
      const opts = c.options ? ` — opciones: ${c.options.join(', ')}` : '';
      const note =
        c.key === 'observaciones'
          ? ' — se inserta en el historial de observaciones'
          : '';
      return `• ${c.header}${req}${opts}${note}`;
    }),
  ];
  lines.forEach((line, i) => {
    help.getCell(i + 1, 1).value = line;
  });

  return wb.xlsx.writeBuffer();
}

async function parseRows(buffer, schema) {
  const wb = new ExcelJS.Workbook();
  await wb.xlsx.load(buffer);
  const ws = wb.worksheets[0];
  if (!ws) {
    const err = new Error('El archivo no contiene hojas');
    err.status = 400;
    throw err;
  }

  const headerRow = ws.getRow(1);
  const colMap = buildHeaderMap(headerRow, schema);
  if (!Object.values(colMap).includes('ci')) {
    const err = new Error('Falta la columna Cédula en la plantilla');
    err.status = 400;
    throw err;
  }

  const rows = [];
  ws.eachRow({ includeEmpty: false }, (row, rowNumber) => {
    if (rowNumber === 1) return;
    const values = [];
    row.eachCell({ includeEmpty: true }, (cell, colNumber) => {
      values[colNumber] = cell.value;
    });
    if (isRowEmpty(values)) return;

    const data = {};
    for (const [colNumber, key] of Object.entries(colMap)) {
      const raw = values[Number(colNumber)];
      const str = cellToString(raw);
      if (str !== '') data[key] = str;
    }
    rows.push({ fila: rowNumber, data });
  });

  return rows;
}

async function upsertObservacion(client, entidad, entidadId, texto) {
  if (!texto || !String(texto).trim()) return;
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

function buildPersonaData(data, schema) {
  const persona = {};
  for (const key of schema.personaFields) {
    if (data[key] !== undefined && data[key] !== '') {
      persona[key] = data[key];
    }
  }
  return persona;
}

function buildModuleData(data, schema, estatusInfo) {
  const module = {};
  for (const col of schema.insertColumns) {
    if (data[col] === undefined || data[col] === '') continue;
    if (col === 'estatus' && estatusInfo?.estatus) {
      module[col] = estatusInfo.estatus;
    } else {
      module[col] = data[col];
    }
  }
  return module;
}

function validateRow(data, schema) {
  const ci = normalizeCi(data.ci);
  if (!ci) {
    const err = new Error('Sin cédula');
    err.status = 400;
    throw err;
  }

  const persona = buildPersonaData({ ...data, ci }, schema);

  const estatusInfo = data.estatus
    ? normalizeEstatus(data.estatus)
    : { estatus: null, original: null };

  if (schema.isVolunteer && estatusInfo.estatus) {
    if (!['Activo', 'Inactivo'].includes(estatusInfo.estatus)) {
      estatusInfo.estatus = 'Inactivo';
    }
  }

  const validatedPersona = { ci };
  for (const [key, val] of Object.entries(persona)) {
    if (key === 'ci') continue;
    if (key.startsWith('fecha')) {
      validatedPersona[key] = coerceColumn(key, val);
    } else {
      validatedPersona[key] = optionalString(val);
    }
  }

  const validatedModule = {};
  const moduleRaw = buildModuleData(data, schema, estatusInfo);
  for (const [key, val] of Object.entries(moduleRaw)) {
    validatedModule[key] = coerceColumn(key, val);
  }

  return {
    ci,
    persona: validatedPersona,
    module: validatedModule,
    estatusInfo,
    observaciones: optionalString(data.observaciones),
  };
}

/**
 * Busca registro del módulo para upsert.
 * - Voluntarios (matchColumns vacío): un registro por persona.
 * - Estudiantes: persona + columnas de match (año, fecha_inicio, …).
 * - Si todas las columnas de match vienen vacías: actualiza el más reciente
 *   de esa persona (evita crear filas basura solo con nulos).
 */
async function findExistingModuleRow(client, schema, personaId, module) {
  const matchColumns = schema.matchColumns || [];
  const hasMatchCols = matchColumns.length > 0;
  const allMatchEmpty =
    hasMatchCols &&
    matchColumns.every((col) => {
      const v = module[col];
      return v === undefined || v === null || v === '';
    });

  if (!hasMatchCols || allMatchEmpty) {
    const fechaSelect = schema.keepLatest ? ', fecha_inicio::text AS fecha_inicio' : '';
    const result = await client.query(
      `SELECT ${schema.idColumn} AS id${fechaSelect} FROM ${schema.table}
       WHERE persona_id = $1
       ORDER BY ${schema.idColumn} DESC
       LIMIT 1`,
      [personaId]
    );
    return result.rows[0] || null;
  }

  const params = [personaId];
  const parts = ['persona_id = $1'];
  for (const col of matchColumns) {
    params.push(module[col] ?? null);
    parts.push(`${col} IS NOT DISTINCT FROM $${params.length}`);
  }

  const result = await client.query(
    `SELECT ${schema.idColumn} AS id FROM ${schema.table}
     WHERE ${parts.join(' AND ')}
     ORDER BY ${schema.idColumn}
     LIMIT 1`,
    params
  );
  return result.rows[0] || null;
}

async function processImport(pool, schema, rows, { dryRun = false } = {}) {
  let creados = 0;
  let actualizados = 0;
  const errores = [];
  const seenInFile = new Set();

  for (const { fila, data } of rows) {
    try {
      const parsed = validateRow(data, schema);

      if (dryRun) {
        // Filas repetidas en el mismo archivo: la segunda actualiza lo que creó la primera.
        const fileKey = [parsed.ci, ...(schema.matchColumns || []).map((c) => parsed.module[c] ?? '')].join('|');
        if (seenInFile.has(fileKey)) {
          actualizados++;
          continue;
        }
        seenInFile.add(fileKey);

        const client = await pool.connect();
        try {
          let persona = await findPersonaByCi(client, parsed.ci);
          let exists = false;
          if (persona) {
            const existing = await findExistingModuleRow(
              client,
              schema,
              persona.persona_id,
              parsed.module
            );
            exists = !!existing;
          }
          if (exists) actualizados++;
          else creados++;
        } finally {
          client.release();
        }
        continue;
      }

      const client = await pool.connect();
      try {
        await client.query('BEGIN');

        let persona = await findPersonaByCi(client, parsed.ci);
        if (persona) {
          persona = await updatePersona(client, persona.persona_id, parsed.persona);
        } else {
          if (!optionalString(parsed.persona.nombre)) {
            throw Object.assign(new Error('Nombre requerido para persona nueva'), { status: 400 });
          }
          persona = await insertPersona(client, parsed.persona);
        }

        const existingMod = await findExistingModuleRow(
          client,
          schema,
          persona.persona_id,
          parsed.module
        );

        let moduleId;

        if (existingMod) {
          moduleId = existingMod.id;
          // keepLatest: una fila con fecha de inicio más antigua que la guardada
          // solo rellena campos vacíos; nunca pisa el registro más reciente.
          const isOlder =
            schema.keepLatest &&
            existingMod.fecha_inicio &&
            parsed.module.fecha_inicio &&
            parsed.module.fecha_inicio < existingMod.fecha_inicio;
          const sets = [];
          const vals = [];
          for (const [col, val] of Object.entries(parsed.module)) {
            vals.push(val);
            // Estatus siempre se actualiza si viene en el Excel (puede cambiar Iniciando → Culminó).
            // El resto usa COALESCE para no borrar con celdas vacías.
            if (isOlder) {
              sets.push(`${col} = COALESCE(${col}, $${vals.length})`);
            } else if (col === 'estatus') {
              sets.push(`${col} = $${vals.length}`);
            } else {
              sets.push(`${col} = COALESCE($${vals.length}, ${col})`);
            }
          }
          sets.push('activo = TRUE');
          if (sets.length > 1) {
            vals.push(moduleId);
            await client.query(
              `UPDATE ${schema.table} SET ${sets.join(', ')} WHERE ${schema.idColumn} = $${vals.length}`,
              vals
            );
          } else {
            await client.query(
              `UPDATE ${schema.table} SET activo = TRUE WHERE ${schema.idColumn} = $1`,
              [moduleId]
            );
          }
          actualizados++;
        } else {
          const cols = [...schema.insertColumns];
          const vals = cols.map((c) => {
            if (c === 'tipo_actividad' && schema.defaultTipoActividad && !parsed.module[c]) {
              return schema.defaultTipoActividad;
            }
            return parsed.module[c] ?? null;
          });
          const placeholders = cols.map((_, i) => `$${i + 2}`).join(', ');
          const ins = await client.query(
            `INSERT INTO ${schema.table} (persona_id, ${cols.join(', ')}, activo)
             VALUES ($1, ${placeholders}, TRUE)
             RETURNING ${schema.idColumn} AS id`,
            [persona.persona_id, ...vals]
          );
          moduleId = ins.rows[0].id;
          creados++;
        }

        if (
          parsed.estatusInfo.original &&
          parsed.estatusInfo.estatus &&
          parsed.estatusInfo.original !== parsed.estatusInfo.estatus &&
          schema.entidad
        ) {
          await upsertObservacion(
            client,
            schema.entidad,
            moduleId,
            `Estatus original en Excel: ${parsed.estatusInfo.original}`
          );
        }

        if (parsed.observaciones && schema.entidad) {
          await upsertObservacion(
            client,
            schema.entidad,
            moduleId,
            parsed.observaciones
          );
        }

        await client.query('COMMIT');
      } catch (err) {
        await client.query('ROLLBACK');
        throw err;
      } finally {
        client.release();
      }
    } catch (err) {
      errores.push({
        fila,
        motivo: err.message || 'Error desconocido',
      });
    }
  }

  return {
    total: rows.length,
    creados,
    actualizados,
    crear: creados,
    actualizar: actualizados,
    errores,
  };
}

module.exports = {
  buildTemplate,
  parseRows,
  processImport,
  cellToString,
  findExistingModuleRow,
};
