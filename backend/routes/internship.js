const { createCrudRouter } = require('../lib/crudFactory');

module.exports = createCrudRouter({
  table: 'pasantia_tesis_proyecto',
  idColumn: 'pasantia_tesis_proyecto_id',
  entidad: 'pasantia',
  importSchemaKey: 'pasantia',
  selectExtra: `
    m.tipo,
    m.carrera,
    m.instituto,
    m.tutor_academico,
    m.tutor_institucional,
    m.anio,
    m.estatus,
    m.fecha_inicio,
    m.fecha_culminacion
  `,
  insertColumns: [
    'tipo',
    'carrera',
    'instituto',
    'tutor_academico',
    'tutor_institucional',
    'anio',
    'estatus',
    'fecha_inicio',
    'fecha_culminacion',
  ],
});
