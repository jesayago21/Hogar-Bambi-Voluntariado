/**
 * Unifica Labor Social desde el DEF (2016 - jun 2025) y las copias 2025 / 2026.
 * Una persona = un registro. Campo a campo gana el valor más reciente no vacío.
 *
 * Uso (desde backend/):
 *   node scripts/import/merge-labor-social.js --dry-run   # solo Excel + reporte
 *   node scripts/import/merge-labor-social.js             # reemplaza labor_social
 *   node scripts/import/merge-labor-social.js --skip-backup
 */
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const ExcelJS = require('exceljs');
const pool = require('../../db/pool');
const {
  normalizeCi,
  normalizeEstatus,
  normalizeHeader,
  splitNombreApellido,
  stripAccents,
} = require('./normalize');
const { optionalDate } = require('../../lib/validate');
const { findPersonaByCi, insertPersona, updatePersona } = require('../../lib/crudFactory');
const { SCHEMAS } = require('../../lib/importSchemas');

const DOCS = path.join(__dirname, '..', '..', '..', 'docs');
const SRC_DIR = path.join(DOCS, 'SC BAMBI FINAL');
const SOURCES = [
  { key: 'DEF', rank: 0, file: 'Base de Datos DEF (2016 -Jun 2025) - LABOR SOCIAL.xlsx', sheets: ['Integral SC'] },
  { key: '2025', rank: 1, file: 'Copia de Labor Social 2025 (debes incluir la data de Jul a dic 25).xlsx' },
  { key: '2026', rank: 2, file: 'Copia de Labor Social 2026.xlsx' },
];
const OUT_XLSX = path.join(DOCS, 'labor_social_unificado.xlsx');
const OUT_REPORT = path.join(DOCS, 'labor_social_merge_reporte.csv');
const BACKUP_DIR = path.join(DOCS, '..', 'backups');

const PERSONA_FIELDS = ['ci', 'telefono', 'email', 'fecha_induccion'];
const MODULE_FIELDS = [
  'colegio',
  'nivel',
  'carrera',
  'expediente',
  'anio',
  'estatus',
  'fecha_inicio',
  'fecha_culminacion',
  'representante',
  'telefono_representante',
  'email_representante',
  'actividad_apoyo',
  'fecha_carta_culminacion',
];
const DATE_FIELDS = new Set(['fecha_induccion', 'fecha_inicio', 'fecha_culminacion', 'fecha_carta_culminacion']);

// Encabezado normalizado → campo. Teléfono / Email repetidos: el segundo es del representante.
const HEADER_ALIASES = {
  ano: 'anio',
  estatus: 'estatus',
  'nombre y apellido': 'nombreFull',
  participante: 'nombreFull',
  'cedula de identidad': 'ci',
  cedula: 'ci',
  email: 'email',
  correo: 'email',
  'email representante': 'email_representante',
  telefono: 'telefono',
  telefono2: 'telefono_representante',
  'fecha de induccion': 'fecha_induccion',
  'colegio / instituto': 'colegio',
  colegio: 'colegio',
  carrera: 'carrera',
  nivel: 'nivel',
  representante: 'representante',
  'actividad de apoyo': 'actividad_apoyo',
  'fecha de inicio': 'fecha_inicio',
  inicio: 'fecha_inicio',
  'fecha de culminacion': 'fecha_culminacion',
  culminacion: 'fecha_culminacion',
  'carta culminacion digital': 'fecha_carta_culminacion',
  observaciones: 'observaciones',
  otro: 'expediente',
};
const SECOND_OCCURRENCE = { telefono: 'telefono_representante', email: 'email_representante' };

function cellValue(v) {
  if (v === undefined || v === null) return null;
  if (v instanceof Date) return v;
  if (typeof v === 'object') {
    if (Array.isArray(v.richText)) return v.richText.map((t) => t.text).join('');
    if (v.text !== undefined) return cellValue(v.text);
    if (v.result !== undefined) return cellValue(v.result);
    if (v.error) return null;
    return null;
  }
  return v;
}

function cellText(v) {
  const c = cellValue(v);
  if (c === null || c === undefined) return null;
  if (c instanceof Date) return c.toISOString().slice(0, 10);
  const s = String(c).replace(/\s+/g, ' ').trim();
  return s === '' ? null : s;
}

function toDate(v) {
  const c = cellValue(v);
  if (c === null || c === undefined || c === '') return null;
  try {
    return optionalDate(c);
  } catch (_) {
    return null;
  }
}

function toYear(v) {
  const c = cellValue(v);
  if (c === null || c === undefined) return null;
  const n = parseInt(String(c).replace(/\D/g, ''), 10);
  return n >= 2000 && n <= 2100 ? n : null;
}

function normName(full) {
  if (!full) return null;
  const n = stripAccents(String(full)).toLowerCase().replace(/[^a-z\s]/g, ' ').replace(/\s+/g, ' ').trim();
  return n || null;
}

function rowCells(ws, r) {
  const row = ws.getRow(r);
  const out = [];
  row.eachCell({ includeEmpty: true }, (cell, col) => {
    out[col] = cell.value;
  });
  return out;
}

function buildHeaderMap(cells) {
  const map = {};
  const seen = {};
  cells.forEach((raw, col) => {
    const text = cellText(raw);
    if (!text) return;
    const h = normalizeHeader(text);
    let field = HEADER_ALIASES[h];
    if (!field) return;
    if (seen[field] && SECOND_OCCURRENCE[field]) field = SECOND_OCCURRENCE[field];
    if (seen[field]) return;
    seen[field] = true;
    map[col] = field;
  });
  return map;
}

function isHeaderRow(cells) {
  const texts = cells.map((c) => normalizeHeader(cellText(c) || ''));
  return texts.includes('estatus') && (texts.includes('participante') || texts.includes('nombre y apellido'));
}

function sheetColegio(ws) {
  const r1 = cellText(rowCells(ws, 1).find((c) => cellText(c)));
  if (r1 && r1 !== '<') return r1;
  const r2 = cellText(rowCells(ws, 2).find((c) => cellText(c)));
  if (r2 && r2 !== '<') return r2;
  return ws.name.trim();
}

function parseRecord(cells, headerMap, ctx) {
  const rec = { source: ctx.source, rank: ctx.rank, sheet: ctx.sheet, fila: ctx.fila };
  for (const [col, field] of Object.entries(headerMap)) {
    const raw = cells[Number(col)];
    if (DATE_FIELDS.has(field)) rec[field] = toDate(raw);
    else if (field === 'anio') rec[field] = toYear(raw);
    else if (field === 'ci') rec[field] = normalizeCi(cellText(raw));
    else rec[field] = cellText(raw);
  }
  if (!rec.colegio && ctx.colegio) rec.colegio = ctx.colegio;
  if (!rec.anio && ctx.anio) rec.anio = ctx.anio;
  if (rec.email && !rec.email.includes('@')) rec.email = null;
  if (rec.email) rec.email = rec.email.replace(/^mailto:/i, '');
  if (rec.email_representante) rec.email_representante = rec.email_representante.replace(/^mailto:/i, '');
  const est = normalizeEstatus(rec.estatus);
  rec.estatusOriginal = est.original;
  rec.estatus = est.estatus;
  return rec;
}

async function readSource(src, report) {
  const wb = new ExcelJS.Workbook();
  await wb.xlsx.readFile(path.join(SRC_DIR, src.file));
  const records = [];
  const sheets = src.sheets
    ? wb.worksheets.filter((ws) => src.sheets.includes(ws.name))
    : wb.worksheets;

  for (const ws of sheets) {
    const colegio = src.key === 'DEF' ? null : sheetColegio(ws);
    let headerMap = null;
    let anio = null;

    for (let r = 1; r <= ws.rowCount; r++) {
      const cells = rowCells(ws, r);
      if (isHeaderRow(cells)) {
        headerMap = buildHeaderMap(cells);
        continue;
      }
      const filled = cells.filter((c) => cellText(c));
      if (filled.length === 0) continue;
      // Fila de bloque de año (ej. 2025 repetido en todas las columnas)
      if (src.key !== 'DEF' && filled.every((c) => /^\d{4}$/.test(cellText(c)) && toYear(c))) {
        anio = toYear(filled[0]);
        continue;
      }
      if (!headerMap) continue;

      const rec = parseRecord(cells, headerMap, {
        source: src.key,
        rank: src.rank,
        sheet: ws.name,
        fila: r,
        colegio,
        anio,
      });
      if (!rec.nombreFull && !rec.ci) continue;
      if (!rec.nombreFull) {
        report.push({ tipo: 'sin_nombre', clave: rec.ci, nombre: '', detalle: `${src.key} / ${ws.name} fila ${r}` });
      }
      records.push(rec);
    }
  }
  return records;
}

function sortKey(rec) {
  return [rec.fecha_inicio || (rec.anio ? `${rec.anio}-00-00` : '0000-00-00'), rec.anio || 0, rec.rank, rec.fila];
}

function compareRecords(a, b) {
  const ka = sortKey(a);
  const kb = sortKey(b);
  for (let i = 0; i < ka.length; i++) {
    if (ka[i] < kb[i]) return -1;
    if (ka[i] > kb[i]) return 1;
  }
  return 0;
}

function groupRecords(records, report) {
  const groups = new Map();
  const nameToCis = new Map();

  for (const rec of records) {
    if (!rec.ci) continue;
    if (!groups.has(rec.ci)) groups.set(rec.ci, []);
    groups.get(rec.ci).push(rec);
    const n = normName(rec.nombreFull);
    if (n) {
      if (!nameToCis.has(n)) nameToCis.set(n, new Set());
      nameToCis.get(n).add(rec.ci);
    }
  }

  for (const rec of records) {
    if (rec.ci) continue;
    const n = normName(rec.nombreFull);
    const cis = n ? nameToCis.get(n) : null;
    if (cis && cis.size === 1) {
      groups.get([...cis][0]).push(rec);
      continue;
    }
    if (cis && cis.size > 1) {
      report.push({
        tipo: 'nombre_ambiguo',
        clave: '',
        nombre: rec.nombreFull,
        detalle: `Coincide con varias cédulas: ${[...cis].join(' / ')} (${rec.source} / ${rec.sheet} fila ${rec.fila})`,
      });
    }
    const key = `nombre:${n}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(rec);
  }
  return groups;
}

function mergeGroup(key, recs) {
  const sorted = [...recs].sort(compareRecords);
  const merged = { key, apariciones: sorted.length, fuentes: {} };
  const fields = [...PERSONA_FIELDS, ...MODULE_FIELDS, 'nombreFull'];

  for (const f of fields) {
    for (let i = sorted.length - 1; i >= 0; i--) {
      const v = sorted[i][f];
      if (v !== null && v !== undefined && v !== '') {
        merged[f] = v;
        merged.fuentes[f] = sorted[i].source;
        if (f === 'estatus') merged.estatusOriginal = sorted[i].estatusOriginal;
        break;
      }
    }
    if (merged[f] === undefined) merged[f] = null;
  }

  const obs = [];
  for (const r of sorted) {
    if (r.observaciones && !obs.includes(r.observaciones)) obs.push(r.observaciones);
  }
  if (merged.estatusOriginal && merged.estatus && merged.estatusOriginal !== merged.estatus) {
    obs.push(`Estatus original en Excel: ${merged.estatusOriginal}`);
  }
  merged.observaciones = obs;
  merged.origenes = [...new Set(sorted.map((r) => (r.source === 'DEF' ? 'DEF' : `${r.source}:${r.sheet.trim()}`)))];
  merged.enDef = sorted.some((r) => r.source === 'DEF');
  merged.enCopias = sorted.some((r) => r.source !== 'DEF');
  const { nombre, apellido } = splitNombreApellido(merged.nombreFull);
  merged.nombre = nombre;
  merged.apellido = apellido;
  return merged;
}

function fmtDate(iso) {
  if (!iso) return '';
  const [y, m, d] = iso.split('-');
  return `${d}/${m}/${y}`;
}

async function writeExcel(merged) {
  const cols = SCHEMAS.labor_social.columns;
  const wb = new ExcelJS.Workbook();
  const ws = wb.addWorksheet('Labor Social', { views: [{ state: 'frozen', ySplit: 1 }] });
  const headers = [...cols.map((c) => c.header), 'Fuente', 'Apariciones'];
  ws.addRow(headers).font = { bold: true };
  cols.forEach((c, i) => {
    ws.getColumn(i + 1).width = c.width || 16;
  });
  ws.getColumn(cols.length + 1).width = 40;

  for (const m of merged) {
    const values = cols.map((c) => {
      if (c.key === 'nombre') return m.nombre;
      if (c.key === 'apellido') return m.apellido;
      if (c.key === 'observaciones') return m.observaciones.join(' | ');
      const v = m[c.key];
      if (DATE_FIELDS.has(c.key)) return fmtDate(v);
      return v ?? '';
    });
    ws.addRow([...values, m.origenes.join(', '), m.apariciones]);
  }
  await wb.xlsx.writeFile(OUT_XLSX);
}

function writeReport(report) {
  const esc = (v) => `"${String(v ?? '').replace(/"/g, '""')}"`;
  const lines = report.map((r) => [r.tipo, r.clave, r.nombre, r.detalle].map(esc).join(','));
  fs.writeFileSync(OUT_REPORT, '\uFEFFtipo,clave,nombre,detalle\n' + lines.join('\n'), 'utf8');
}

function backupDatabase() {
  if (!fs.existsSync(BACKUP_DIR)) fs.mkdirSync(BACKUP_DIR, { recursive: true });
  const stamp = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 12);
  const out = path.join(BACKUP_DIR, `antes_merge_ls_${stamp}.dump`);
  const container = 'voluntariado_db_local';
  const tmp = `/tmp/antes_merge_ls_${stamp}.dump`;
  execSync(`docker exec ${container} pg_dump -U postgres -d voluntariado_hogar_bambi -F c -f ${tmp}`, { stdio: 'inherit' });
  execSync(`docker cp ${container}:${tmp} "${out}"`, { stdio: 'inherit' });
  execSync(`docker exec ${container} rm -f ${tmp}`);
  return out;
}

async function findPersonaSinCi(client, nombre, apellido) {
  const r = await client.query(
    `SELECT * FROM personas
     WHERE COALESCE(ci, '') = ''
       AND lower(btrim(nombre)) = lower(btrim($1))
       AND lower(btrim(apellido)) = lower(btrim($2))
     LIMIT 1`,
    [nombre, apellido]
  );
  return r.rows[0] || null;
}

async function writeDatabase(merged) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(`DELETE FROM observaciones WHERE entidad = 'labor_social'`);
    await client.query('DELETE FROM labor_social');

    for (const m of merged) {
      const personaData = {
        ci: m.ci,
        nombre: m.nombre,
        apellido: m.apellido,
        telefono: m.telefono,
        email: m.email,
        fecha_induccion: m.fecha_induccion,
      };
      let persona = m.ci
        ? await findPersonaByCi(client, m.ci)
        : await findPersonaSinCi(client, m.nombre, m.apellido);
      persona = persona
        ? await updatePersona(client, persona.persona_id, personaData)
        : await insertPersona(client, personaData);

      const vals = MODULE_FIELDS.map((f) => m[f] ?? null);
      const placeholders = MODULE_FIELDS.map((_, i) => `$${i + 2}`).join(', ');
      const ins = await client.query(
        `INSERT INTO labor_social (persona_id, ${MODULE_FIELDS.join(', ')}, activo)
         VALUES ($1, ${placeholders}, TRUE)
         RETURNING labor_social_id AS id`,
        [persona.persona_id, ...vals]
      );
      for (const texto of m.observaciones) {
        await client.query(
          `INSERT INTO observaciones (entidad, entidad_id, texto, origen)
           VALUES ('labor_social', $1, $2, 'importacion')`,
          [ins.rows[0].id, texto]
        );
      }
    }

    const orphans = await client.query(`
      DELETE FROM personas p
      WHERE NOT EXISTS (SELECT 1 FROM voluntarios v WHERE v.persona_id = p.persona_id)
        AND NOT EXISTS (SELECT 1 FROM labor_social ls WHERE ls.persona_id = p.persona_id)
        AND NOT EXISTS (SELECT 1 FROM servicio_comunitario_universitario sc WHERE sc.persona_id = p.persona_id)
        AND NOT EXISTS (SELECT 1 FROM pasantia_tesis_proyecto ptp WHERE ptp.persona_id = p.persona_id)
        AND NOT EXISTS (SELECT 1 FROM otros o WHERE o.persona_id = p.persona_id)
    `);
    await client.query('COMMIT');
    return { personasHuerfanas: orphans.rowCount };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function main() {
  const dryRun = process.argv.includes('--dry-run');
  const skipBackup = process.argv.includes('--skip-backup');
  const report = [];

  const all = [];
  const porFuente = {};
  for (const src of SOURCES) {
    const recs = await readSource(src, report);
    porFuente[src.key] = recs.length;
    all.push(...recs);
  }

  const groups = groupRecords(all, report);
  const merged = [];
  for (const [key, recs] of groups) {
    const m = mergeGroup(key, recs);
    if (!m.nombreFull) {
      report.push({ tipo: 'descartado_sin_nombre', clave: key, nombre: '', detalle: m.origenes.join(', ') });
      continue;
    }
    if (!m.ci) {
      report.push({ tipo: 'sin_cedula', clave: '', nombre: m.nombreFull, detalle: m.origenes.join(', ') });
    }
    merged.push(m);
  }
  merged.sort((a, b) => (a.nombreFull || '').localeCompare(b.nombreFull || '', 'es'));

  const stats = {
    filasLeidas: porFuente,
    personasUnicas: merged.length,
    soloDef: merged.filter((m) => m.enDef && !m.enCopias).length,
    defActualizadasConCopias: merged.filter((m) => m.enDef && m.enCopias).length,
    nuevasDesdeCopias: merged.filter((m) => !m.enDef).length,
    conVariasApariciones: merged.filter((m) => m.apariciones > 1).length,
    sinCedula: merged.filter((m) => !m.ci).length,
    nombresAmbiguos: report.filter((r) => r.tipo === 'nombre_ambiguo').length,
  };

  await writeExcel(merged);
  writeReport(report);
  console.log(dryRun ? '=== DRY RUN (no se toca la BD) ===' : '=== MERGE LABOR SOCIAL ===');
  console.log(JSON.stringify(stats, null, 2));
  console.log('Excel unificado:', OUT_XLSX);
  console.log('Reporte:', OUT_REPORT);

  if (dryRun) {
    await pool.end();
    return;
  }

  if (!skipBackup) {
    console.log('Respaldo previo...');
    console.log('Guardado en:', backupDatabase());
  }

  const res = await writeDatabase(merged);
  const count = await pool.query('SELECT count(*)::int AS n FROM labor_social');
  console.log('labor_social ahora:', count.rows[0].n);
  console.log('Personas huérfanas eliminadas:', res.personasHuerfanas);
  await pool.end();
}

main().catch(async (err) => {
  console.error(err);
  try {
    await pool.end();
  } catch (_) {}
  process.exit(1);
});
