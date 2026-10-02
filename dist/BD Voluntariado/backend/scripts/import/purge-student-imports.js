/**
 * Elimina registros de estudiantes/otros importados por CSV.
 * Conserva voluntarios y personas que solo tienen fila en voluntarios.
 *
 * Uso:
 *   node scripts/import/purge-student-imports.js           # vista previa (no borra)
 *   node scripts/import/purge-student-imports.js --confirm # borra de verdad
 */
const pool = require('../../db/pool');

async function preview(client) {
  const conn = await client.query(
    'SELECT current_database() AS db, inet_server_addr() AS host, inet_server_port() AS port'
  );
  const { db, host, port } = conn.rows[0];

  const count = async (sql) => {
    const r = await client.query(sql);
    return r.rows[0].n;
  };

  const counts = {
    observaciones_estudiantes: await count(`
      SELECT count(*)::int AS n FROM observaciones
      WHERE entidad IN ('labor_social', 'servicio_comunitario', 'pasantia', 'otros')
    `),
    labor_social: await count('SELECT count(*)::int AS n FROM labor_social'),
    servicio_comunitario: await count(
      'SELECT count(*)::int AS n FROM servicio_comunitario_universitario'
    ),
    pasantia_tesis_proyecto: await count(
      'SELECT count(*)::int AS n FROM pasantia_tesis_proyecto'
    ),
    otros: await count('SELECT count(*)::int AS n FROM otros'),
    personas_huerfanas: await count(`
      SELECT count(*)::int AS n FROM personas p
      WHERE NOT EXISTS (SELECT 1 FROM voluntarios v WHERE v.persona_id = p.persona_id)
        AND NOT EXISTS (SELECT 1 FROM labor_social ls WHERE ls.persona_id = p.persona_id)
        AND NOT EXISTS (
          SELECT 1 FROM servicio_comunitario_universitario sc WHERE sc.persona_id = p.persona_id
        )
        AND NOT EXISTS (
          SELECT 1 FROM pasantia_tesis_proyecto ptp WHERE ptp.persona_id = p.persona_id
        )
        AND NOT EXISTS (SELECT 1 FROM otros o WHERE o.persona_id = p.persona_id)
    `),
    // After deleting student modules, orphan count would include current student-only personas
    personas_que_quedarian_huerfanas: await count(`
      SELECT count(*)::int AS n FROM personas p
      WHERE NOT EXISTS (SELECT 1 FROM voluntarios v WHERE v.persona_id = p.persona_id)
    `),
    voluntarios_conservados: await count('SELECT count(*)::int AS n FROM voluntarios'),
  };

  console.log('=== PURGE PREVIEW (estudiantes/otros) ===');
  console.log(`Conectado a: database=${db} host=${host || 'localhost'} port=${port}`);
  console.log('Filas que se borrarían:');
  console.log('  observaciones (estudiantes/otros):', counts.observaciones_estudiantes);
  console.log('  labor_social:', counts.labor_social);
  console.log('  servicio_comunitario:', counts.servicio_comunitario);
  console.log('  pasantia_tesis_proyecto:', counts.pasantia_tesis_proyecto);
  console.log('  otros:', counts.otros);
  console.log(
    '  personas huérfanas (sin voluntario, tras borrar módulos):',
    counts.personas_que_quedarian_huerfanas
  );
  console.log('Conservados:');
  console.log('  voluntarios:', counts.voluntarios_conservados);
  console.log('');

  return counts;
}

async function purge(client) {
  await client.query('BEGIN');

  const obs = await client.query(`
    DELETE FROM observaciones
    WHERE entidad IN ('labor_social', 'servicio_comunitario', 'pasantia', 'otros')
  `);

  const ls = await client.query('DELETE FROM labor_social RETURNING labor_social_id');
  const sc = await client.query(
    'DELETE FROM servicio_comunitario_universitario RETURNING servicio_comunitario_id'
  );
  const pt = await client.query(
    'DELETE FROM pasantia_tesis_proyecto RETURNING pasantia_tesis_proyecto_id'
  );
  const ot = await client.query('DELETE FROM otros RETURNING otros_id');

  const orphanPersonas = await client.query(`
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
    RETURNING persona_id
  `);

  await client.query('COMMIT');

  console.log('Purge complete:');
  console.log('  observaciones (estudiantes/otros):', obs.rowCount);
  console.log('  labor_social:', ls.rowCount);
  console.log('  servicio_comunitario:', sc.rowCount);
  console.log('  pasantia_tesis_proyecto:', pt.rowCount);
  console.log('  otros:', ot.rowCount);
  console.log('  personas huérfanas:', orphanPersonas.rowCount);
}

async function main() {
  const confirm = process.argv.includes('--confirm');
  const client = await pool.connect();
  try {
    await preview(client);

    if (!confirm) {
      console.log('Modo vista previa: no se borró nada.');
      console.log('Para borrar de verdad: npm run import:purge-students -- --confirm');
      return;
    }

    console.log('Ejecutando purga con --confirm...');
    await purge(client);
  } catch (err) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {}
    throw err;
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
