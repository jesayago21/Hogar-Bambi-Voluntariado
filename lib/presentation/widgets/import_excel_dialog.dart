import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:voluntariado_desktop_app/infraestructure/datasources/api_volunteer_datasource_dart.dart';

enum _ImportStep { initial, preview, result }

Future<bool?> showImportExcelDialog({
  required BuildContext context,
  required String titulo,
  required String modulePath,
  required String nombrePlantilla,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ImportExcelDialog(
      titulo: titulo,
      modulePath: modulePath,
      nombrePlantilla: nombrePlantilla,
    ),
  );
}

class _ImportExcelDialog extends StatefulWidget {
  final String titulo;
  final String modulePath;
  final String nombrePlantilla;

  const _ImportExcelDialog({
    required this.titulo,
    required this.modulePath,
    required this.nombrePlantilla,
  });

  @override
  State<_ImportExcelDialog> createState() => _ImportExcelDialogState();
}

class _ImportExcelDialogState extends State<_ImportExcelDialog> {
  _ImportStep _step = _ImportStep.initial;
  bool _busy = false;
  String? _error;

  Uint8List? _fileBytes;
  String? _fileName;

  Map<String, dynamic>? _preview;
  Map<String, dynamic>? _result;

  Future<void> _downloadTemplate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await ApiService.descargarPlantilla(widget.modulePath);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar plantilla Excel',
        fileName: widget.nombrePlantilla,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (path != null) {
        var outPath = path;
        if (!outPath.toLowerCase().endsWith('.xlsx')) {
          outPath = '$outPath.xlsx';
        }
        final file = File(outPath);
        await file.writeAsBytes(bytes, flush: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Plantilla guardada en $outPath')),
          );
        }
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFile() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('No se pudo leer el archivo seleccionado');
      }

      _fileBytes = bytes;
      _fileName = file.name;

      final preview = await ApiService.previewImportacion(
        widget.modulePath,
        bytes,
        file.name,
      );

      if (!mounted) return;
      setState(() {
        _preview = preview;
        _step = _ImportStep.preview;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmImport() async {
    if (_fileBytes == null || _fileName == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ApiService.ejecutarImportacion(
        widget.modulePath,
        _fileBytes!,
        _fileName!,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _step = _ImportStep.result;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Map<String, dynamic>> _errores(Map<String, dynamic>? data) {
    if (data == null) return const [];
    final raw = data['errores'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  int _intVal(Map<String, dynamic>? data, String key) {
    if (data == null) return 0;
    final v = data[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  Widget _rulesNote() {
    return const Text(
      'Use la plantilla sin cambiar los encabezados. Cédula obligatoria. '
      'Fechas en DD/MM/AAAA. Si la cédula ya existe en este módulo, se actualiza.',
      style: TextStyle(fontSize: 13),
    );
  }

  Widget _errorBox() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(_error!, style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _errorsList(List<Map<String, dynamic>> errores) {
    if (errores.isEmpty) {
      return const Text('Sin errores.', style: TextStyle(fontSize: 13));
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: errores.length,
        separatorBuilder: (_, __) => const Divider(height: 8),
        itemBuilder: (_, i) {
          final e = errores[i];
          return Text(
            'Fila ${e['fila']}: ${e['motivo']}',
            style: const TextStyle(fontSize: 13),
          );
        },
      ),
    );
  }

  Widget _buildInitial() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _rulesNote(),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _busy ? null : _downloadTemplate,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Descargar plantilla'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy ? null : _pickFile,
          icon: const Icon(Icons.upload_file),
          label: const Text('Seleccionar archivo lleno'),
        ),
        _errorBox(),
      ],
    );
  }

  Widget _buildPreview() {
    final preview = _preview!;
    final errores = _errores(preview);
    final crear = _intVal(preview, 'crear');
    final actualizar = _intVal(preview, 'actualizar');
    final total = _intVal(preview, 'total');
    final valid = crear + actualizar > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Archivo: $_fileName', style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        Text('Filas leídas: $total'),
        Text('Se crearán: $crear'),
        Text('Se actualizarán: $actualizar'),
        Text('Errores: ${errores.length}'),
        const SizedBox(height: 8),
        _errorsList(errores),
        _errorBox(),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _step = _ImportStep.initial;
                        _preview = null;
                        _fileBytes = null;
                        _fileName = null;
                      }),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _busy || !valid ? null : _confirmImport,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirmar importación'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResult() {
    final result = _result!;
    final errores = _errores(result);
    final creados = _intVal(result, 'creados');
    final actualizados = _intVal(result, 'actualizados');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Importación completada', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('Creados: $creados'),
        Text('Actualizados: $actualizados'),
        Text('Errores: ${errores.length}'),
        const SizedBox(height: 8),
        _errorsList(errores),
        _errorBox(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Importar Excel — ${widget.titulo}'),
      content: SizedBox(
        width: 480,
        child: _busy && _step == _ImportStep.initial
            ? const Center(child: CircularProgressIndicator())
            : switch (_step) {
                _ImportStep.initial => _buildInitial(),
                _ImportStep.preview => _buildPreview(),
                _ImportStep.result => _buildResult(),
              },
      ),
      actions: [
        if (_step == _ImportStep.result)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar'),
          )
        else if (_step == _ImportStep.initial)
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cerrar'),
          ),
      ],
    );
  }
}
