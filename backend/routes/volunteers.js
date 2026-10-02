const { createCrudRouter } = require('../lib/crudFactory');

module.exports = createCrudRouter({
  table: 'voluntarios',
  idColumn: 'voluntario_id',
  entidad: 'voluntario',
  importSchemaKey: 'voluntarios',
  nameAlias: true,
  selectExtra: `
    m.fecha_inicio,
    m.fecha_retiro,
    m.estatus AS status,
    m.profesion_oficio,
    m.lugar_trabajo AS institucion,
    m.asistencias,
    m.actividad
  `,
  insertColumns: [
    'fecha_inicio',
    'fecha_retiro',
    'estatus',
    'profesion_oficio',
    'lugar_trabajo',
    'asistencias',
    'actividad',
  ],
});
