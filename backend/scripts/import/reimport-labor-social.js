/**
 * Borra SOLO labor_social (+ observaciones) e importa el CSV DEF completo.
 *
 * Uso (desde backend/):
 *   node scripts/import/reimport-labor-social.js
 */
const path = require('path');
const pool = require('../../db/pool');
const { importEstudiantes, MODULE_CONFIGS } = require('./importEstudiantes');

const CSV = path.join(
  __dirname,
  '..',
  '..',
  '..',
  'docs',
  'backup',
  'Base de Datos DEF (2016 -Jun 2025) - LABOR SOCIAL.xlsx - Integral SC.csv'
);

async function purgeLaborSocial(client) {
  const before = await client.query('SELECT count(*)::int AS n FROM labor_social');
  console.log('labor_social antes:', before.rows[0].n);

  await client.query('BEGIN');
  const obs = await client.query(
    `DELETE FROM observaciones WHERE entidad = 'labor_social'`
  );
  const ls = await client.query('DELETE FROM labor_social');
  const personas = await client.query(`
    DELETE FROM personas p
    WHERE NOT EXISTS (SELECT 1 FROM voluntarios v WHERE v.persona_id = p.persona_id)
      AND NOT EXISTS (SELECT 1 FROM labor_social ls WHERE ls.persona_id = p.persona_id)
      AND NOT EXISTS (
        SELECT 1 FROM servicio_comunitario_universitario sc WHERE sc.persona_id = p.persona_id
      )
      AND NOT EXISTS (
        SELECT 1 FROM pasantia_tesis_proyecto ptp WHERE ptp.persona_id = p.persona_id
      )
      AND NOT EXISTS (SELECT 1 FROM otros o WHERE o.persona_id = p.persona_id)
  `);
  await client.query('COMMIT');

  console.log('Borradas observaciones LS:', obs.rowCount);
  console.log('Borradas filas labor_social:', ls.rowCount);
  console.log('Personas huérfanas eliminadas (solo tenían LS):', personas.rowCount);
}

async function main() {
  const fs = require('fs');
  if (!fs.existsSync(CSV)) {
    console.error('No encuentro el CSV:', CSV);
    process.exit(1);
  }

  const client = await pool.connect();
  try {
    await purgeLaborSocial(client);
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    throw err;
  } finally {
    client.release();
  }

  console.log('\nImportando desde:', path.basename(CSV));
  const rejected = [];
  const summary = await importEstudiantes(pool, CSV, MODULE_CONFIGS.labor_social, {
    dryRun: false,
    rejected,
  });

  console.log('\n=== RESULTADO ===');
  console.log(summary);
  console.log('Rechazos / avisos:', rejected.length);

  const after = await pool.query('SELECT count(*)::int AS n FROM labor_social');
  console.log('labor_social ahora:', after.rows[0].n);

  if (rejected.length) {
    const out = path.join(__dirname, '..', '..', '..', 'docs', 'importacion-rechazados-ls.csv');
    const header = 'modulo,linea,motivo,nombre,ci\n';
    const lines = rejected.map((r) =>
      [r.modulo, r.linea, r.motivo, r.nombre || '', r.ci || '']
        .map((v) => `"${String(v ?? '').replace(/"/g, '""')}"`)
        .join(',')
    );
    fs.writeFileSync(out, header + lines.join('\n'), 'utf8');
    console.log('Reporte:', out);
  }

  await pool.end();
}

main().catch(async (err) => {
  console.error(err);
  try {
    await pool.end();
  } catch (_) {}
  process.exit(1);
});
