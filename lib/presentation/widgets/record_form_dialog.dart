import 'package:flutter/material.dart';
import 'package:voluntariado_desktop_app/presentation/utils/date_search.dart';
import 'package:voluntariado_desktop_app/presentation/utils/form_body.dart';

class FormFieldDesc {
  final String key;
  final String label;
  final String? initialValue;
  final TextInputType keyboardType;
  final int maxLines;
  final bool requiredField;
  final bool isDate;

  const FormFieldDesc({
    required this.key,
    required this.label,
    this.initialValue,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.requiredField = false,
    this.isDate = false,
  });
}

Future<Map<String, String>?> showRecordFormDialog({
  required BuildContext context,
  required String title,
  required List<FormFieldDesc> fields,
}) {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (ctx) => _RecordFormDialog(title: title, fields: fields),
  );
}

class _RecordFormDialog extends StatefulWidget {
  final String title;
  final List<FormFieldDesc> fields;

  const _RecordFormDialog({required this.title, required this.fields});

  @override
  State<_RecordFormDialog> createState() => _RecordFormDialogState();
}

class _RecordFormDialogState extends State<_RecordFormDialog> {
  late final Map<String, TextEditingController> _controllers;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final f in widget.fields)
        f.key: TextEditingController(text: f.initialValue ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(FormFieldDesc f) async {
    final current = parseFormDate(_controllers[f.key]?.text);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      _controllers[f.key]!.text = formatFechaCorta(picked);
      _error = null;
    });
  }

  void _submit() {
    for (final f in widget.fields) {
      final text = _controllers[f.key]?.text.trim() ?? '';
      if (f.requiredField && text.isEmpty) {
        setState(() => _error = 'Campo requerido: ${f.label}');
        return;
      }
      if (f.isDate && text.isNotEmpty && toApiDate(text) == null) {
        setState(
          () => _error = 'Fecha inválida en ${f.label}. Usa DD/MM/AAAA',
        );
        return;
      }
    }

    final map = <String, String>{};
    for (final f in widget.fields) {
      final text = _controllers[f.key]!.text.trim();
      if (f.isDate && text.isNotEmpty) {
        map[f.key] = toApiDate(text)!;
      } else {
        map[f.key] = text;
      }
    }
    Navigator.pop(context, map);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              ...widget.fields.map((f) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _controllers[f.key],
                    readOnly: f.isDate,
                    onTap: f.isDate ? () => _pickDate(f) : null,
                    keyboardType: f.isDate
                        ? TextInputType.datetime
                        : f.keyboardType,
                    maxLines: f.maxLines,
                    decoration: InputDecoration(
                      labelText: f.requiredField ? '${f.label} *' : f.label,
                      hintText: f.isDate ? 'DD/MM/AAAA' : null,
                      border: const OutlineInputBorder(),
                      suffixIcon: f.isDate
                          ? IconButton(
                              tooltip: 'Elegir fecha',
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () => _pickDate(f),
                            )
                          : null,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
