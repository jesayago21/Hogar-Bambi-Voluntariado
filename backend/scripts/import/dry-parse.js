/**
 * Parse-only dry check (no DB). Usage: node scripts/import/dry-parse.js
 */
const path = require('path');
const fs = require('fs');
const { parseCsvFile } = require('./parseCsv');
const {
  normalizeCi,
  splitNombreApellido,
  parseFlexibleDate,
  normalizeEstatus,
  getField,
} = require('./normalize');

const DOCS = path.join(__dirname, '..', '..', '..', 'docs');

const matchers = {
  voluntarios: (n) => n.includes('VOLUNTARIOS') && n.endsWith('.csv'),
  labor: (n) => n.includes('LABOR SOCIAL') && n.endsWith('.csv'),
  sc: (n) => n.includes('SERVICIO COMUNITARIO') && n.endsWith('.csv'),
  pasantia: (n) => n.toLowerCase().includes('pasantia') && n.endsWith('.csv'),
  postgrado: (n) =>
    n.toLowerCase().includes('post') && n.endsWith('.csv'),
};

function resolve(m) {
  return fs.readdirSync(DOCS).find(m);
}

for (const [name, matcher] of Object.entries(matchers)) {
  const file = resolve(matcher);
  if (!file) {
    console.log(name + ': MISSING');
    continue;
  }
  const hints =
    name === 'voluntarios'
      ? ['estatus', 'participante', 'ci']
      : ['estatus', 'nombre'];
  const rows = parseCsvFile(path.join(DOCS, file), { headerHints: hints });
  let ok = 0;
  let noCi = 0;
  let badStatus = 0;
  for (const row of rows) {
    const ci = normalizeCi(
      getField(row, ['CI', 'Cédula de Identidad', 'Cedula de Identidad'])
    );
    const est = normalizeEstatus(getField(row, ['Estatus']));
    if (!ci) noCi++;
    else ok++;
    if (!est.estatus) badStatus++;
  }
  console.log(
    `${name}: file=${file} rows=${rows.length} withCi=${ok} noCi=${noCi} noStatus=${badStatus}`
  );
  if (rows[0]) {
    const sample = rows[0];
    const full = getField(sample, ['Participante', 'Nombre y Apellido']);
    console.log(
      '  sample:',
      splitNombreApellido(full),
      'ci=',
      normalizeCi(getField(sample, ['CI', 'Cédula de Identidad'])),
      'inicio=',
      parseFlexibleDate(getField(sample, ['Fecha de Inicio'])).date,
      'estatus=',
      normalizeEstatus(getField(sample, ['Estatus'])).estatus
    );
  }
}
