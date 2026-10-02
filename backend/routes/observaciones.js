const express = require('express');
const pool = require('../db/pool');
const { parseId, required, optionalString } = require('../lib/validate');

const router = express.Router();

const ENTIDADES = new Set([
  'voluntario',
  'labor_social',
  'servicio_comunitario',
  'pasantia',
  'otros',
]);

const ENTITY_MOUNT = {
  volunteers: 'voluntario',
  labor_social: 'labor_social',
  community_service: 'servicio_comunitario',
  internship_thesis_project: 'pasantia',
  others: 'otros',
};

function entityFromParam(entidad) {
  if (ENTIDADES.has(entidad)) return entidad;
  if (ENTITY_MOUNT[entidad]) return ENTITY_MOUNT[entidad];
  return null;
}

// Nested: /api/:mount/:id/observaciones — mounted per module in server.js
function createNestedRouter(entidadFija) {
  const nested = express.Router({ mergeParams: true });

  nested.get('/', async (req, res) => {
    try {
      const entidad = entidadFija || entityFromParam(req.params.entidad);
      if (!entidad) return res.status(400).json({ error: 'Entidad inválida' });
      const id = parseId(req.params.id);
      const result = await pool.query(
        `SELECT observacion_id AS id, entidad, entidad_id, texto, fecha, autor, origen
         FROM observaciones
         WHERE entidad = $1 AND entidad_id = $2
         ORDER BY fecha DESC`,
        [entidad, id]
      );
      res.json(result.rows);
    } catch (err) {
      const status = err.status || 500;
      res.status(status).json({ error: err.message || 'Error al listar observaciones' });
    }
  });

  nested.post('/', async (req, res) => {
    try {
      const entidad = entidadFija || entityFromParam(req.params.entidad);
      if (!entidad) return res.status(400).json({ error: 'Entidad inválida' });
      const id = parseId(req.params.id);
      const texto = required(req.body?.texto, 'texto');
      const autor = optionalString(req.body?.autor);
      const origen = optionalString(req.body?.origen) || 'manual';
      const result = await pool.query(
        `INSERT INTO observaciones (entidad, entidad_id, texto, autor, origen)
         VALUES ($1,$2,$3,$4,$5)
         RETURNING observacion_id AS id, entidad, entidad_id, texto, fecha, autor, origen`,
        [entidad, id, String(texto).trim(), autor, origen]
      );
      res.status(201).json(result.rows[0]);
    } catch (err) {
      const status = err.status || 500;
      res.status(status).json({ error: err.message || 'Error al crear observación' });
    }
  });

  return nested;
}

// Direct: PUT/DELETE /api/observaciones/:id
router.put('/:id', async (req, res) => {
  try {
    const id = parseId(req.params.id);
    const texto = required(req.body?.texto, 'texto');
    const result = await pool.query(
      `UPDATE observaciones SET texto = $1
       WHERE observacion_id = $2
       RETURNING observacion_id AS id, entidad, entidad_id, texto, fecha, autor, origen`,
      [String(texto).trim(), id]
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Observación no encontrada' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    const status = err.status || 500;
    res.status(status).json({ error: err.message || 'Error al actualizar observación' });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const id = parseId(req.params.id);
    const result = await pool.query(
      `DELETE FROM observaciones WHERE observacion_id = $1 RETURNING observacion_id AS id`,
      [id]
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Observación no encontrada' });
    }
    res.json({ message: 'Observación eliminada', id: result.rows[0].id });
  } catch (err) {
    const status = err.status || 500;
    res.status(status).json({ error: err.message || 'Error al eliminar observación' });
  }
});

module.exports = router;
module.exports.createNestedRouter = createNestedRouter;
