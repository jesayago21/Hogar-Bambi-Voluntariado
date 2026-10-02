/// Formato corto para listas (dd/MM/yyyy).
String formatFechaCorta(DateTime? d) {
  if (d == null) return 'Sin fecha';
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}

bool _matchesFechaInicio(String q, DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final yyyy = d.year.toString();
  final corta = formatFechaCorta(d).toLowerCase();

  final variants = <String>[
    corta,
    '$dd/$mm/$yyyy',
    '${d.day}/${d.month}/$yyyy',
    '$yyyy-$mm-$dd',
    '$mm/$yyyy',
    '${d.month}/$yyyy',
    yyyy,
  ];

  // Año completo o consultas con separador de fecha.
  final looksLikeDate = q.length >= 4 || q.contains('/') || q.contains('-');
  if (!looksLikeDate) return false;

  return variants.any((v) => v.contains(q));
}

/// Coincide nombre, apellido, CI, correo, institución o fecha de inicio.
bool matchesPersonaSearch(
  String query, {
  required String nombre,
  required String apellido,
  required String ci,
  DateTime? fechaInicio,
  String? email,
  String? institucion,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;

  if (nombre.toLowerCase().contains(q) ||
      apellido.toLowerCase().contains(q) ||
      '${nombre.toLowerCase()} ${apellido.toLowerCase()}'.contains(q) ||
      ci.toLowerCase().contains(q)) {
    return true;
  }

  final mail = email?.trim().toLowerCase() ?? '';
  if (mail.isNotEmpty && mail.contains(q)) return true;

  final inst = institucion?.trim().toLowerCase() ?? '';
  if (inst.isNotEmpty && inst.contains(q)) return true;

  if (fechaInicio == null) return false;
  return _matchesFechaInicio(q, fechaInicio);
}
