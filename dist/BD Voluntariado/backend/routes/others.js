const { createCrudRouter } = require('../lib/crudFactory');

module.exports = createCrudRouter({
  table: 'otros',
  idColumn: 'otros_id',
  entidad: 'otros',
  importSchemaKey: 'otros',
  selectExtra: `
    m.tipo_actividad,
    m.institucion,
    m.carrera,
    m.anio,
    m.estatus,
    m.fecha_inicio,
    m.fecha_culminacion
  `,
  insertColumns: [
    'tipo_actividad',
    'institucion',
    'carrera',
    'anio',
    'estatus',
    'fecha_inicio',
    'fecha_culminacion',
  ],
});
