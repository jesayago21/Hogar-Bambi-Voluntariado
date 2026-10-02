const fs = require('fs');
const { parse } = require('csv-parse/sync');

/**
 * Parse a CSV file, skipping leading non-header rows until a row that looks like headers.
 * @param {string} filePath
 * @param {{ skipLines?: number, headerHints?: string[] }} options
 */
function parseCsvFile(filePath, options = {}) {
  const raw = fs.readFileSync(filePath, 'utf8');
  // Strip BOM
  const content = raw.replace(/^\uFEFF/, '');
  const lines = content.split(/\r?\n/);

  let start = options.skipLines || 0;
  if (options.headerHints && options.headerHints.length) {
    for (let i = 0; i < Math.min(lines.length, 15); i++) {
      const lower = lines[i].toLowerCase();
      if (options.headerHints.every((h) => lower.includes(h.toLowerCase()))) {
        start = i;
        break;
      }
    }
  }

  const slice = lines.slice(start).join('\n');
  const records = parse(slice, {
    columns: true,
    skip_empty_lines: true,
    relax_column_count: true,
    relax_quotes: true,
    trim: true,
    bom: true,
  });
  return records;
}

module.exports = { parseCsvFile };
