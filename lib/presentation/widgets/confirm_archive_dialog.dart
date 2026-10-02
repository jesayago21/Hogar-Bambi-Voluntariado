import 'package:flutter/material.dart';

Future<bool> showConfirmArchiveDialog({
  required BuildContext context,
  required String nombre,
  bool restoring = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(restoring ? 'Restaurar registro' : 'Archivar registro'),
      content: Text(
        restoring
            ? '¿Restaurar a "$nombre"?'
            : '¿Archivar a "$nombre"? El registro no se borrará definitivamente.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(restoring ? 'Restaurar' : 'Archivar'),
        ),
      ],
    ),
  );
  return result == true;
}

/// Confirmación para borrado definitivo (solo desde archivados).
Future<bool> showConfirmPermanentDeleteDialog({
  required BuildContext context,
  required String nombre,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Eliminar definitivamente'),
      content: Text(
        '¿Eliminar de forma permanente a "$nombre"?\n\n'
        'Esta acción no se puede deshacer. El registro y sus observaciones se borrarán.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return result == true;
}
