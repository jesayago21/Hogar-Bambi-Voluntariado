function normalizeCi(raw) {
  if (raw === undefined || raw === null) return null;
  let s = String(raw).trim();
  if (!s) return null;
  // Keep passport-like values
  if (/[A-Za-z]/.test(s) && !/^\d[\d.\s]*$/.test(s)) {
    return s.replace(/\s+/g, ' ').trim();
  }
  const digits = s.replace(/[^\d]/g, '');
  return digits || null;
}

function splitNombreApellido(full) {
  if (!full) return { nombre: '', apellido: '' };
  const cleaned = String(full).replace(/\s+/g, ' ').trim();
  if (!cleaned) return { nombre: '', apellido: '' };
  const parts = cleaned.split(' ');
  if (parts.length === 1) return { nombre: parts[0], apellido: '' };
  if (parts.length === 2) return { nombre: parts[0], apellido: parts[1] };
  return {
    nombre: parts.slice(0, -2).join(' '),
    apellido: parts.slice(-2).join(' '),
  };
}

/**
 * Parse dates that may be d/m/y or m/d/y or ISO.
 * Returns { date: 'YYYY-MM-DD'|null, ambiguous: boolean, raw: string }
 */
function parseFlexibleDate(raw) {
  if (raw === undefined || raw === null) {
    return { date: null, ambiguous: false, raw: null };
  }
  let s = String(raw).trim();
  if (!s) return { date: null, ambiguous: false, raw: null };

  const noteMatch = s.match(/^(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})/);
  if (noteMatch) s = noteMatch[1];

  const iso = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/);
  if (iso) {
    const y = iso[1];
    const m = String(iso[2]).padStart(2, '0');
    const d = String(iso[3]).padStart(2, '0');
    return { date: `${y}-${m}-${d}`, ambiguous: false, raw: String(raw) };
  }

  const mdy = s.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})$/);
  if (!mdy) {
    return { date: null, ambiguous: true, raw: String(raw) };
  }

  let a = Number(mdy[1]);
  let b = Number(mdy[2]);
  let y = Number(mdy[3]);
  if (y < 100) y += 2000;

  if (a > 12 && b <= 12) {
    return {
      date: `${y}-${String(b).padStart(2, '0')}-${String(a).padStart(2, '0')}`,
      ambiguous: false,
      raw: String(raw),
    };
  }
  if (b > 12 && a <= 12) {
    return {
      date: `${y}-${String(a).padStart(2, '0')}-${String(b).padStart(2, '0')}`,
      ambiguous: false,
      raw: String(raw),
    };
  }
  if (a <= 12 && b <= 12) {
    return {
      date: `${y}-${String(b).padStart(2, '0')}-${String(a).padStart(2, '0')}`,
      ambiguous: a !== b,
      raw: String(raw),
    };
  }

  return { date: null, ambiguous: true, raw: String(raw) };
}

const ESTATUS_CANON = [
  'Culminó',
  'En proceso',
  'Iniciando',
  'Sin iniciar',
  'Se retiró',
  'Suspendido',
  'Pausado',
  'Activo',
  'Inactivo',
];

function stripAccents(s) {
  return s.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

function normalizeHeader(s) {
  return stripAccents(String(s || ''))
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

function normalizeEstatus(raw) {
  if (raw === undefined || raw === null) {
    return { estatus: null, original: null };
  }
  const original = String(raw).trim();
  if (!original) return { estatus: null, original: null };

  const n = stripAccents(original).toLowerCase().replace(/\s+/g, ' ').trim();

  if (n === 'activo') return { estatus: 'Activo', original };
  if (n.startsWith('inactivo')) return { estatus: 'Inactivo', original };

  if (n.startsWith('culmino') || n.includes('entrego informe')) {
    return { estatus: 'Culminó', original };
  }
  if (n.includes('retiro') || n.includes('retiro')) {
    return { estatus: 'Se retiró', original };
  }
  if (n.includes('se retiro') || n.includes('retir')) {
    return { estatus: 'Se retiró', original };
  }
  if (n.includes('suspend')) return { estatus: 'Suspendido', original };
  if (n.includes('pausado')) return { estatus: 'Pausado', original };
  if (n.includes('sin iniciar') || n.includes('no inicio') || n.includes('no inició')) {
    return { estatus: 'Sin iniciar', original };
  }
  if (n.includes('en proceso') || n.includes('2da rotacion') || n.includes('iniciando o en proceso')) {
    return { estatus: 'En proceso', original };
  }
  if (
    n.includes('iniciando') ||
    n.includes('inicio') ||
    n.startsWith('inici') ||
    n.includes('puede iniciar') ||
    n.includes('iniciara') ||
    n.includes('esperando') ||
    n.includes('propuesta') ||
    n.includes('falta') ||
    n.includes('envio') ||
    n.includes('envi') ||
    n.includes('autorizacion') ||
    n.includes('en espera')
  ) {
    return { estatus: 'Iniciando', original };
  }
  if (n.includes('egreso')) return { estatus: 'Culminó', original };
  if (n.includes('inconcluso') || n.includes('leer observ') || n.includes('ver observ') || n.includes('no hay registros')) {
    return { estatus: 'Pausado', original };
  }

  return { estatus: 'Iniciando', original };
}

function getField(row, candidates) {
  const keys = Object.keys(row);
  for (const c of candidates) {
    const found = keys.find(
      (k) => k.trim().toLowerCase() === c.toLowerCase()
    );
    if (found && row[found] !== undefined && row[found] !== null && String(row[found]).trim() !== '') {
      return String(row[found]).trim();
    }
  }
  for (const c of candidates) {
    const found = keys.find((k) =>
      k.trim().toLowerCase().includes(c.toLowerCase())
    );
    if (found && row[found] !== undefined && String(row[found]).trim() !== '') {
      return String(row[found]).trim();
    }
  }
  return null;
}

module.exports = {
  normalizeCi,
  splitNombreApellido,
  parseFlexibleDate,
  normalizeEstatus,
  getField,
  normalizeHeader,
  stripAccents,
  ESTATUS_CANON,
};
