const fs = require('fs');
const path = require('path');
const pool = require('../../db/pool');
const { runMigrations } = require('../../db/migrations/run');
const { importVoluntarios } = require('./importVoluntarios');
const { importEstudiantes, MODULE_CONFIGS } = require('./importEstudiantes');

const DOCS = path.join(__dirname, '..', '..', '..', 'docs');
const BACKUP = path.join(DOCS, 'backup');

const FILE_MATCHERS = {
  voluntarios: (n) => n.includes('VOLUNTARIOS') && n.toLowerCase().endsWith('.csv'),
  labor_social: (n) => {
    const l = n.toLowerCase();
    return (
      l.endsWith('.csv') &&
      (l.includes('labor social') || l.includes('bdd ls') || /\bls\b/.test(l))
    );
  },
  servicio_comunitario: (n) =>
    n.includes('SERVICIO COMUNITARIO') && n.toLowerCase().endsWith('.csv'),
  pasantia: (n) => n.toLowerCase().includes('pasantia') && n.toLowerCase().endsWith('.csv'),
  postgrado: (n) =>
    (n.toLowerCase().includes('post grado') || n.toLowerCase().includes('postgrado')) &&
    n.toLowerCase().endsWith('.csv'),
};

function resolveFile(matcher, searchDir = DOCS) {
  if (!fs.existsSync(searchDir)) return null;
  const files = fs.readdirSync(searchDir);
  const hit = files.find(matcher);
  return hit ? path.join(searchDir, hit) : null;
}

function writeRejected(rejected) {
  const out = path.join(DOCS, 'importacion-rechazados.csv');
  const header = 'modulo,linea,motivo,nombre,ci,raw\n';
  const escape = (v) => {
    if (v == null) return '';
    const s = String(v).replace(/"/g, '""');
    return `"${s}"`;

  };
  const lines = rejected.map((r) =>
    [r.modulo, r.linea, r.motivo, r.nombre, r.ci, r.raw]
      .map(escape)
      .join(',')
  );
  fs.writeFileSync(out, header + lines.join('\n'), 'utf8');
  console.log(`Rejected report: ${out} (${rejected.length} rows)`);
}

async function main() {
  const dryRun = process.argv.includes('--dry-run');
  const importAll = process.argv.includes('--all-modules');
  console.log(dryRun ? '=== DRY RUN ===' : '=== IMPORT ===');
  console.log(
    importAll
      ? 'Modo: todos los módulos (CSV en docs/ o docs/backup/)'
      : 'Modo: solo cuadro general de voluntarios (docs/)'
  );

  if (!dryRun) {
    console.log('Running migrations...');
    await runMigrations();
  }

  const rejected = [];
  const summaries = [];

  const volPath = resolveFile(FILE_MATCHERS.voluntarios);
  if (volPath) {
    console.log('Importing voluntarios from', path.basename(volPath));
    summaries.push(await importVoluntarios(pool, volPath, { dryRun, rejected }));
  } else {
    console.warn('Missing cuadro gral CSV in docs/ (nombre debe contener VOLUNTARIOS)');
  }

  if (importAll) {
    for (const key of ['labor_social', 'servicio_comunitario', 'pasantia', 'postgrado']) {
      const filePath =
        resolveFile(FILE_MATCHERS[key], DOCS) ||
        resolveFile(FILE_MATCHERS[key], BACKUP);
      if (!filePath) {
        console.warn(`Missing CSV for ${key}`);
        continue;
      }
      console.log(`Importing ${key} from`, path.basename(filePath));
      summaries.push(
        await importEstudiantes(pool, filePath, MODULE_CONFIGS[key], {
          dryRun,
          rejected,
        })
      );
    }
  }

  console.log('\n=== SUMMARY ===');
  for (const s of summaries) {
    console.log(
      `${s.modulo}: total=${s.total} created=${s.created} updated=${s.updated} skipped=${s.skipped}`
    );
  }

  writeRejected(rejected);
  await pool.end();
}

main().catch(async (err) => {
  console.error(err);
  try {
    await pool.end();
  } catch (_) {}
  process.exit(1);
});
