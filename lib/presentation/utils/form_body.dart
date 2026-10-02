import 'package:voluntariado_desktop_app/presentation/utils/date_search.dart';

const dateFieldKeys = {
  'fecha_nacimiento',
  'fecha_induccion',
  'fecha_inicio',
  'fecha_retiro',
  'fecha_culminacion',
  'birth_date',
};

const intFieldKeys = {'anio', 'asistencias'};

/// Convierte texto de fecha a YYYY-MM-DD (API/Postgres).
/// Acepta AAAA-MM-DD, DD/MM/AAAA, D/M/AA.
String? toApiDate(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  if (s.isEmpty) return null;

  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
  if (iso != null) {
    final y = iso.group(1)!;
    final m = iso.group(2)!.padLeft(2, '0');
    final d = iso.group(3)!.padLeft(2, '0');
    return '$y-$m-$d';
  }

  final note = RegExp(r'^(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})').firstMatch(s);
  if (note != null) s = note.group(1)!;

  final parts = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$').firstMatch(s);
  if (parts == null) return null;

  var a = int.parse(parts.group(1)!);
  var b = int.parse(parts.group(2)!);
  var y = int.parse(parts.group(3)!);
  if (y < 100) y += 2000;

  late int day;
  late int month;
  if (a > 12 && b <= 12) {
    day = a;
    month = b;
  } else if (b > 12 && a <= 12) {
    day = b;
    month = a;
  } else {
    day = a;
    month = b;
  }

  try {
    final dt = DateTime(y, month, day);
    if (dt.year != y || dt.month != month || dt.day != day) return null;
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return null;
  }
}

DateTime? parseFormDate(String? raw) {
  final api = toApiDate(raw);
  if (api == null) return null;
  return DateTime.tryParse(api);
}

String? fechaInicialForm(DateTime? d) =>
    d == null ? null : formatFechaCorta(d);

/// Arma el body JSON omitiendo vacíos y normalizando fechas/enteros.
Map<String, dynamic> buildApiBody(Map<String, String> m) {
  final out = <String, dynamic>{};
  for (final e in m.entries) {
    final raw = e.value.trim();
    if (raw.isEmpty) continue;

    if (dateFieldKeys.contains(e.key)) {
      final d = toApiDate(raw);
      if (d == null) {
        throw FormatException(
          'Fecha inválida en ${e.key}: "$raw". Usa DD/MM/AAAA',
        );
      }
      out[e.key] = d;
      continue;
    }

    if (intFieldKeys.contains(e.key)) {
      final n = int.tryParse(raw);
      if (n == null) {
        throw FormatException('Número inválido en ${e.key}: "$raw"');
      }
      out[e.key] = n;
      continue;
    }

    out[e.key] = raw;
  }
  return out;
}
