const { createCrudRouter } = require('../lib/crudFactory');

module.exports = createCrudRouter({
  table: 'servicio_comunitario_universitario',
  idColumn: 'servicio_comunitario_id',
  entidad: 'servicio_comunitario',
  importSchemaKey: 'servicio_comunitario',
  selectExtra: `
    m.instituto,
    m.carrera,
    m.proyecto,
    m.anio,
    m.estatus,
    m.fecha_inicio,
    m.fecha_culminacion
  `,
  insertColumns: [
    'instituto',
    'carrera',
    'proyecto',
    'anio',
    'estatus',
    'fecha_inicio',
    'fecha_culminacion',
  ],
});
