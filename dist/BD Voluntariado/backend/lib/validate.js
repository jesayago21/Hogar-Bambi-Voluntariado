function required(value, field) {
  if (value === undefined || value === null || String(value).trim() === '') {
    const err = new Error(`Campo requerido: ${field}`);
    err.status = 400;
    throw err;
  }
  return value;
}

function optionalString(value) {
  if (value === undefined || value === null) return null;
  const s = String(value).trim();
  return s === '' ? null : s;
}

function optionalInt(value) {
  if (value === undefined || value === null || value === '') return null;
  const n = Number(value);
  if (Number.isNaN(n)) {
    const err = new Error('Valor numérico inválido');
    err.status = 400;
    throw err;
  }
  return n;
}

/**
 * Acepta YYYY-MM-DD, DD/MM/YYYY, D/M/YY, etc.
 * Vacío → null. Inválido → Error 400.
 * Prefiere día/mes/año (locale VE) cuando es ambiguo.
 */
function optionalDate(value) {
  if (value === undefined || value === null || value === '') return null;
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    const y = value.getUTCFullYear();
    const m = String(value.getUTCMonth() + 1).padStart(2, '0');
    const d = String(value.getUTCDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  let s = String(value).trim();
  if (!s) return null;

  // Quitar hora ISO si viene "2024-07-16T00:00:00.000Z"
  const isoFull = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (isoFull) {
    return `${isoFull[1]}-${isoFull[2]}-${isoFull[3]}`;
  }

  const noteMatch = s.match(/^(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})/);
  if (noteMatch) s = noteMatch[1];

  const parts = s.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})$/);
  if (!parts) {
    const err = new Error(
      `Fecha inválida: "${value}". Usa DD/MM/AAAA o AAAA-MM-DD`
    );
    err.status = 400;
    throw err;
  }

  let a = Number(parts[1]);
  let b = Number(parts[2]);
  let y = Number(parts[3]);
  if (y < 100) y += 2000;

  let day;
  let month;
  if (a > 12 && b <= 12) {
    day = a;
    month = b;
  } else if (b > 12 && a <= 12) {
    day = b;
    month = a;
  } else {
    // Ambiguo: preferir DD/MM/YYYY
    day = a;
    month = b;
  }

  if (month < 1 || month > 12 || day < 1 || day > 31) {
    const err = new Error(`Fecha inválida: "${value}"`);
    err.status = 400;
    throw err;
  }

  const dt = new Date(Date.UTC(y, month - 1, day));
  if (
    dt.getUTCFullYear() !== y ||
    dt.getUTCMonth() !== month - 1 ||
    dt.getUTCDate() !== day
  ) {
    const err = new Error(`Fecha inválida: "${value}"`);
    err.status = 400;
    throw err;
  }

  return `${y}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

function parseId(param) {
  const id = Number(param);
  if (!param || Number.isNaN(id)) {
    const err = new Error('ID inválido');
    err.status = 400;
    throw err;
  }
  return id;
}

const DATE_COLUMNS = new Set([
  'fecha_nacimiento',
  'fecha_induccion',
  'fecha_inicio',
  'fecha_retiro',
  'fecha_culminacion',
  'fecha_carta_culminacion',
]);

const INT_COLUMNS = new Set(['anio', 'asistencias']);

function coerceColumn(col, value) {
  if (DATE_COLUMNS.has(col)) return optionalDate(value);
  if (INT_COLUMNS.has(col)) return optionalInt(value);
  if (value === undefined) return null;
  if (value === null) return null;
  if (typeof value === 'string' && value.trim() === '') return null;
  return value;
}

module.exports = {
  required,
  optionalString,
  optionalInt,
  optionalDate,
  parseId,
  DATE_COLUMNS,
  INT_COLUMNS,
  coerceColumn,
};
