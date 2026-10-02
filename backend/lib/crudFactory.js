const pool = require('../db/pool');
const {
  required,
  optionalString,
  optionalInt,
  optionalDate,
  parseId,
  coerceColumn,
} = require('./validate');
const multer = require('multer');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    const ok =
      file.mimetype ===
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ||
      file.originalname.toLowerCase().endsWith('.xlsx');
    cb(ok ? null : new Error('Solo se aceptan archivos .xlsx'), ok);
  },
});

const PERSONA_FIELDS = [
  'ci',
  'nombre',
  'apellido',
  'telefono',
  'email',
  'fecha_nacimiento',
  'residencia',
  'fecha_induccion',
];

function normalizeCi(ci) {
  if (!ci) return null;
  return String(ci).replace(/[^0-9A-Za-z]/g, '');
}

async function findPersonaByCi(client, ci) {
  const norm = normalizeCi(ci);
  if (!norm) return null;
  const result = await client.query(
    `SELECT * FROM personas
     WHERE regexp_replace(ci, '[^0-9A-Za-z]', '', 'g') = $1
     LIMIT 1`,
    [norm]
  );
  return result.rows[0] || null;
}

async function insertPersona(client, data) {
  const result = await client.query(
    `INSERT INTO personas
      (ci, nombre, apellido, telefono, email, fecha_nacimiento, residencia, fecha_induccion, activo)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,TRUE)
     RETURNING *`,
    [
      optionalString(data.ci),
      optionalString(data.nombre) || '',
      optionalString(data.apellido) || '',
      optionalString(data.telefono),
      optionalString(data.email),
      optionalDate(data.fecha_nacimiento),
      optionalString(data.residencia),
      optionalDate(data.fecha_induccion),
    ]
  );
  return result.rows[0];
}

async function updatePersona(client, personaId, data) {
  const result = await client.query(
    `UPDATE personas SET
      ci = COALESCE($1, ci),
      nombre = COALESCE($2, nombre),
      apellido = COALESCE($3, apellido),
      telefono = COALESCE($4, telefono),
      email = COALESCE($5, email),
      fecha_nacimiento = COALESCE($6, fecha_nacimiento),
      residencia = COALESCE($7, residencia),
      fecha_induccion = COALESCE($8, fecha_induccion)
     WHERE persona_id = $9
     RETURNING *`,
    [
      optionalString(data.ci),
      optionalString(data.nombre),
      optionalString(data.apellido),
      optionalString(data.telefono),
      optionalString(data.email),
      optionalDate(data.fecha_nacimiento),
      optionalString(data.residencia),
      optionalDate(data.fecha_induccion),
      personaId,
    ]
  );
  return result.rows[0];
}

/**
 * config:
 * - table, idColumn, entidad (for observaciones)
 * - selectExtra: SQL fragment of module columns (with table alias `m`)
 * - insertColumns: string[] of module columns (excluding id, persona_id, activo)
 * - nameAlias: if true, alias p.nombre AS name and birth_date (volunteers)
 * - defaultTipoActividad: for others/postgrado
 */
function createCrudRouter(config) {
  const express = require('express');
  const router = express.Router();
  const alias = config.tableAlias || 'm';
  const personaSelect = config.nameAlias
    ? `p.persona_id,
       p.ci,
       p.nombre AS name,
       p.apellido,
       p.telefono,
       p.email,
       p.fecha_nacimiento AS birth_date,
       p.residencia,
       p.fecha_induccion,
       p.activo AS persona_activo`
    : `p.persona_id,
       p.ci,
       p.nombre,
       p.apellido,
       p.telefono,
       p.email,
       p.fecha_nacimiento,
       p.residencia,
       p.fecha_induccion,
       p.activo AS persona_activo`;

  const baseSelect = `
    SELECT
      ${alias}.${config.idColumn} AS id,
      ${alias}.persona_id AS module_persona_id,
      ${alias}.activo,
      ${config.selectExtra},
      ${personaSelect}
    FROM ${config.table} ${alias}
    INNER JOIN personas p ON ${alias}.persona_id = p.persona_id
  `;

  router.get('/', async (req, res) => {
    try {
      const incluirArchivados = req.query.incluirArchivados === 'true';
      const soloArchivados = req.query.soloArchivados === 'true';
      const q = optionalString(req.query.q);
      const tipo = optionalString(req.query.tipo_actividad);
      const params = [];
      const where = [];

      if (soloArchivados) {
        where.push(`${alias}.activo = FALSE`);
      } else if (!incluirArchivados) {
        where.push(`${alias}.activo = TRUE`);
      }
      if (q) {
        params.push(`%${q}%`);
        where.push(
          `(p.nombre ILIKE $${params.length} OR p.apellido ILIKE $${params.length} OR p.ci ILIKE $${params.length} OR COALESCE(p.email,'') ILIKE $${params.length})`
        );
      }
      if (tipo && config.table === 'otros') {
        params.push(tipo);
        where.push(`${alias}.tipo_actividad = $${params.length}`);
      }

      let sql = baseSelect;
      if (where.length) sql += ` WHERE ${where.join(' AND ')}`;
      sql += ` ORDER BY ${alias}.fecha_inicio DESC NULLS LAST, p.apellido NULLS LAST, p.nombre NULLS LAST`;

      const result = await pool.query(sql, params);
      res.json(result.rows);
    } catch (err) {
      console.error(`GET ${config.table}:`, err);
      res.status(500).json({ error: `Error al listar ${config.table}` });
    }
  });

  if (config.importSchemaKey) {
    const { getSchemaByKey } = require('./importSchemas');
    const { buildTemplate, parseRows, processImport } = require('./importXlsx');
    const importSchema = getSchemaByKey(config.importSchemaKey);
    if (importSchema) {
      importSchema.defaultTipoActividad = config.defaultTipoActividad;

      router.get('/plantilla', async (_req, res) => {
        try {
          const buffer = await buildTemplate(importSchema);
          res.setHeader(
            'Content-Type',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
          );
          res.setHeader(
            'Content-Disposition',
            `attachment; filename="${importSchema.fileName}"`
          );
          res.send(Buffer.from(buffer));
        } catch (err) {
          console.error(`GET plantilla ${config.table}:`, err);
          res.status(500).json({ error: 'Error al generar plantilla' });
        }
      });

      router.post('/importar', (req, res, next) => {
        upload.single('archivo')(req, res, (err) => {
          if (err) {
            return res.status(400).json({ error: err.message || 'Archivo inválido' });
          }
          next();
        });
      }, async (req, res) => {
        try {
          if (!req.file || !req.file.buffer) {
            return res.status(400).json({ error: 'No se recibió archivo .xlsx' });
          }
          const rows = await parseRows(req.file.buffer, importSchema);
          if (rows.length === 0) {
            return res.status(400).json({ error: 'El archivo no contiene filas de datos' });
          }
          const preview = req.query.preview === 'true';
          const result = await processImport(pool, importSchema, rows, {
            dryRun: preview,
          });
          res.json(result);
        } catch (err) {
          console.error(`POST importar ${config.table}:`, err);
          const status = err.status || 500;
          res.status(status).json({ error: err.message || 'Error al importar' });
        }
      });
    }
  }

  router.get('/:id', async (req, res) => {
    if (req.params.id === 'plantilla' || req.params.id === 'importar') {
      return res.status(503).json({
        error:
          'Importación Excel no disponible. Cierre y vuelva a ejecutar npm start en backend/.',
      });
    }
    try {
      const id = parseId(req.params.id);
      const result = await pool.query(
        `${baseSelect} WHERE ${alias}.${config.idColumn} = $1`,
        [id]
      );
      if (result.rowCount === 0) {
        return res.status(404).json({ error: 'Registro no encontrado' });
      }
      res.json(result.rows[0]);
    } catch (err) {
      const status = err.status || 500;
      res.status(status).json({ error: err.message || 'Error al obtener registro' });
    }
  });

  router.post('/', async (req, res) => {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const body = req.body || {};
      const personaData = {};
      for (const f of PERSONA_FIELDS) {
        if (body[f] !== undefined) personaData[f] = body[f];
      }
      // Allow nested persona object
      if (body.persona && typeof body.persona === 'object') {
        for (const f of PERSONA_FIELDS) {
          if (body.persona[f] !== undefined) personaData[f] = body.persona[f];
        }
      }

      if (body.name !== undefined) personaData.nombre = body.name;
      if (body.birth_date !== undefined) personaData.fecha_nacimiento = body.birth_date;
      if (body.institucion !== undefined && config.table === 'voluntarios') {
        body.lugar_trabajo = body.institucion;
      }
      if (body.status !== undefined && config.table === 'voluntarios') {
        body.estatus = body.status;
      }

      required(personaData.nombre || personaData.ci, 'nombre o ci');

      let persona = null;
      if (personaData.ci) {
        persona = await findPersonaByCi(client, personaData.ci);
      }
      if (persona && config.uniquePerPersona) {
        const dup = await client.query(
          `SELECT 1 FROM ${config.table} WHERE persona_id = $1 LIMIT 1`,
          [persona.persona_id]
        );
        if (dup.rowCount > 0) {
          throw Object.assign(
            new Error(config.duplicateMessage || 'Esta cédula ya tiene un registro en este módulo; edítalo'),
            { status: 409 }
          );
        }
      }

      if (persona) {
        persona = await updatePersona(client, persona.persona_id, personaData);
      } else {
        persona = await insertPersona(client, personaData);
      }

      const cols = [...config.insertColumns];
      const vals = cols.map((c) => {
        if (c === 'tipo_actividad' && config.defaultTipoActividad && (body[c] == null || body[c] === '')) {
          return config.defaultTipoActividad;
        }
        if (body[c] !== undefined) return coerceColumn(c, body[c]);
        return null;
      });

      const placeholders = cols.map((_, i) => `$${i + 2}`).join(', ');
      const insertSql = `
        INSERT INTO ${config.table} (persona_id, ${cols.join(', ')}, activo)
        VALUES ($1, ${placeholders}, TRUE)
        RETURNING ${config.idColumn} AS id
      `;
      const inserted = await client.query(insertSql, [persona.persona_id, ...vals]);
      const newId = inserted.rows[0].id;

      await client.query('COMMIT');

      const full = await pool.query(
        `${baseSelect} WHERE ${alias}.${config.idColumn} = $1`,
        [newId]
      );
      res.status(201).json(full.rows[0]);
    } catch (err) {
      await client.query('ROLLBACK');
      console.error(`POST ${config.table}:`, err);
      const status = err.status || 500;
      res.status(status).json({ error: err.message || 'Error al crear registro' });
    } finally {
      client.release();
    }
  });

  router.put('/:id', async (req, res) => {
    const client = await pool.connect();
    try {
      const id = parseId(req.params.id);
      await client.query('BEGIN');
      const body = req.body || {};

      const existing = await client.query(
        `SELECT * FROM ${config.table} WHERE ${config.idColumn} = $1`,
        [id]
      );
      if (existing.rowCount === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Registro no encontrado' });
      }
      const row = existing.rows[0];

      const personaData = {};
      for (const f of PERSONA_FIELDS) {
        if (body[f] !== undefined) personaData[f] = body[f];
      }
      if (body.persona && typeof body.persona === 'object') {
        for (const f of PERSONA_FIELDS) {
          if (body.persona[f] !== undefined) personaData[f] = body.persona[f];
        }
      }
      // Volunteers use name / birth_date aliases from client sometimes
      if (body.name !== undefined) personaData.nombre = body.name;
      if (body.birth_date !== undefined) personaData.fecha_nacimiento = body.birth_date;
      if (body.institucion !== undefined && config.table === 'voluntarios') {
        body.lugar_trabajo = body.institucion;
      }
      if (body.status !== undefined && config.table === 'voluntarios') {
        body.estatus = body.status;
      }

      if (Object.keys(personaData).length > 0) {
        await updatePersona(client, row.persona_id, personaData);
      }

      const sets = [];
      const vals = [];
      for (const col of config.insertColumns) {
        if (body[col] !== undefined) {
          vals.push(coerceColumn(col, body[col]));
          sets.push(`${col} = $${vals.length}`);
        }
      }
      if (sets.length > 0) {
        vals.push(id);
        await client.query(
          `UPDATE ${config.table} SET ${sets.join(', ')} WHERE ${config.idColumn} = $${vals.length}`,
          vals
        );
      }

      await client.query('COMMIT');
      const full = await pool.query(
        `${baseSelect} WHERE ${alias}.${config.idColumn} = $1`,
        [id]
      );
      res.json(full.rows[0]);
    } catch (err) {
      await client.query('ROLLBACK');
      console.error(`PUT ${config.table}:`, err);
      const status = err.status || 500;
      res.status(status).json({ error: err.message || 'Error al actualizar' });
    } finally {
      client.release();
    }
  });

  router.delete('/:id', async (req, res) => {
    try {
      const id = parseId(req.params.id);
      const result = await pool.query(
        `UPDATE ${config.table} SET activo = FALSE WHERE ${config.idColumn} = $1 RETURNING ${config.idColumn} AS id`,
        [id]
      );
      if (result.rowCount === 0) {
        return res.status(404).json({ error: 'Registro no encontrado' });
      }
      res.json({ message: 'Registro archivado', id: result.rows[0].id });
    } catch (err) {
      const status = err.status || 500;
      res.status(status).json({ error: err.message || 'Error al archivar' });
    }
  });

  router.post('/:id/restaurar', async (req, res) => {
    try {
      const id = parseId(req.params.id);
      const result = await pool.query(
        `UPDATE ${config.table} SET activo = TRUE WHERE ${config.idColumn} = $1 RETURNING ${config.idColumn} AS id`,
        [id]
      );
      if (result.rowCount === 0) {
        return res.status(404).json({ error: 'Registro no encontrado' });
      }
      const full = await pool.query(
        `${baseSelect} WHERE ${alias}.${config.idColumn} = $1`,
        [id]
      );
      res.json(full.rows[0]);
    } catch (err) {
      const status = err.status || 500;
      res.status(status).json({ error: err.message || 'Error al restaurar' });
    }
  });

  /**
   * Borrado definitivo: solo si el registro ya está archivado (activo = FALSE).
   * Elimina observaciones del módulo, la fila del módulo y la persona si queda huérfana.
   */
  router.delete('/:id/permanente', async (req, res) => {
    const client = await pool.connect();
    try {
      const id = parseId(req.params.id);
      await client.query('BEGIN');

      const existing = await client.query(
        `SELECT ${config.idColumn} AS id, persona_id, activo
         FROM ${config.table}
         WHERE ${config.idColumn} = $1
         FOR UPDATE`,
        [id]
      );
      if (existing.rowCount === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Registro no encontrado' });
      }
      const row = existing.rows[0];
      if (row.activo !== false) {
        await client.query('ROLLBACK');
        return res.status(400).json({
          error:
            'Solo se pueden eliminar definitivamente registros archivados. Archívalo primero.',
        });
      }

      if (config.entidad) {
        await client.query(
          `DELETE FROM observaciones WHERE entidad = $1 AND entidad_id = $2`,
          [config.entidad, id]
        );
      }

      await client.query(
        `DELETE FROM ${config.table} WHERE ${config.idColumn} = $1`,
        [id]
      );

      const orphan = await client.query(
        `DELETE FROM personas p
         WHERE p.persona_id = $1
           AND NOT EXISTS (SELECT 1 FROM voluntarios v WHERE v.persona_id = p.persona_id)
           AND NOT EXISTS (SELECT 1 FROM labor_social ls WHERE ls.persona_id = p.persona_id)
           AND NOT EXISTS (
             SELECT 1 FROM servicio_comunitario_universitario sc WHERE sc.persona_id = p.persona_id
           )
           AND NOT EXISTS (
             SELECT 1 FROM pasantia_tesis_proyecto ptp WHERE ptp.persona_id = p.persona_id
           )
           AND NOT EXISTS (SELECT 1 FROM otros o WHERE o.persona_id = p.persona_id)
         RETURNING persona_id`,
        [row.persona_id]
      );

      await client.query('COMMIT');
      res.json({
        message: 'Registro eliminado definitivamente',
        id,
        persona_eliminada: orphan.rowCount > 0,
      });
    } catch (err) {
      await client.query('ROLLBACK');
      console.error(`DELETE permanente ${config.table}:`, err);
      const status = err.status || 500;
      res.status(status).json({ error: err.message || 'Error al eliminar' });
    } finally {
      client.release();
    }
  });

  return router;
}

module.exports = {
  createCrudRouter,
  findPersonaByCi,
  insertPersona,
  updatePersona,
  normalizeCi,
  optionalString,
  optionalInt,
  optionalDate,
};
