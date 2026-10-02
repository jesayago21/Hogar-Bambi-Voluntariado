import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:voluntariado_desktop_app/domain/volunteer/entities/volunteer.dart';
import 'package:voluntariado_desktop_app/infraestructure/datasources/api_volunteer_datasource_dart.dart';
import 'package:voluntariado_desktop_app/presentation/utils/form_body.dart';
import 'package:voluntariado_desktop_app/presentation/widgets/confirm_archive_dialog.dart';
import 'package:voluntariado_desktop_app/presentation/widgets/data_table_list.dart';
import 'package:voluntariado_desktop_app/presentation/widgets/detail_layout.dart';
import 'package:voluntariado_desktop_app/presentation/widgets/observaciones_panel.dart';
import 'package:voluntariado_desktop_app/presentation/widgets/record_form_dialog.dart';

class VoluntarioDetailsScreen extends StatefulWidget {
  final int voluntarioId;

  const VoluntarioDetailsScreen({super.key, required this.voluntarioId});

  @override
  State<VoluntarioDetailsScreen> createState() => _VoluntarioDetailsScreenState();
}

class _VoluntarioDetailsScreenState extends State<VoluntarioDetailsScreen> {
  Voluntario? _voluntario;
  Object? _error;
  bool _loading = true;
  bool _savingAsistencias = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final v = await ApiService.getVoluntarioById(widget.voluntarioId);
      if (!mounted) return;
      setState(() {
        _voluntario = v;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime? date) {
    return date != null ? DateFormat('dd/MM/yyyy').format(date) : 'No registrado';
  }

  int _calcularAnios(DateTime fechaInicio, DateTime? fechaRetiro) {
    final DateTime fin = fechaRetiro ?? DateTime.now();
    return fin.year - fechaInicio.year;
  }

  Future<void> _cambiarEstatus(Voluntario voluntario) async {
    final lower = voluntario.estatus.toLowerCase();
    final nuevoEstatus = lower == 'activo' ? 'Inactivo' : 'Activo';
    final fechaRetiro =
        nuevoEstatus == 'Inactivo' ? DateTime.now().toIso8601String() : null;

    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar estatus'),
        content: Text('¿Seguro que quieres cambiar el estatus a $nuevoEstatus?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );

    if (confirmacion == true) {
      try {
        await ApiService.actualizarEstatusVoluntario(
          voluntario.voluntarioId,
          nuevoEstatus,
          fechaRetiro,
        );
        await _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al actualizar estatus')),
          );
        }
      }
    }
  }

  Future<void> _edit(Voluntario v) async {
    final data = await showRecordFormDialog(
      context: context,
      title: 'Editar voluntario',
      fields: [
        FormFieldDesc(key: 'nombre', label: 'Nombre', initialValue: v.nombre, requiredField: true),
        FormFieldDesc(key: 'apellido', label: 'Apellido', initialValue: v.apellido),
        FormFieldDesc(key: 'ci', label: 'CI', initialValue: v.ci),
        FormFieldDesc(key: 'telefono', label: 'Teléfono', initialValue: v.telefono),
        FormFieldDesc(key: 'email', label: 'Email', initialValue: v.email),
        FormFieldDesc(key: 'residencia', label: 'Residencia', initialValue: v.residencia),
        FormFieldDesc(key: 'profesion_oficio', label: 'Profesión', initialValue: v.profesionOficio),
        FormFieldDesc(key: 'lugar_trabajo', label: 'Lugar de trabajo', initialValue: v.institucion),
        FormFieldDesc(key: 'actividad', label: 'Actividad', initialValue: v.actividad),
        FormFieldDesc(
          key: 'fecha_inicio',
          label: 'Fecha de inicio',
          initialValue: fechaInicialForm(v.fechaInicio),
          isDate: true,
        ),
        FormFieldDesc(
          key: 'fecha_induccion',
          label: 'Fecha de inducción',
          initialValue: fechaInicialForm(v.fechaInduccion),
          isDate: true,
        ),
      ],
    );
    if (data == null) return;
    try {
      final updated = await ApiService.updateVoluntario(v.voluntarioId, buildApiBody(data));
      if (!mounted) return;
      setState(() => _voluntario = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _setAsistencias(int value) async {
    final v = _voluntario;
    if (v == null || _savingAsistencias) return;
    final next = value < 0 ? 0 : value;
    if (next == (v.asistencias ?? 0)) return;

    setState(() => _savingAsistencias = true);
    try {
      final updated = await ApiService.updateVoluntario(
        v.voluntarioId,
        {'asistencias': next},
      );
      if (!mounted) return;
      setState(() {
        _voluntario = updated;
        _savingAsistencias = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingAsistencias = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar asistencias: $e')),
      );
    }
  }

  Future<void> _editarAsistencias() async {
    final v = _voluntario;
    if (v == null || _savingAsistencias) return;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => _AsistenciasEditDialog(initial: v.asistencias ?? 0),
    );
    if (result == null || !mounted) return;
    await _setAsistencias(result);
  }

  Future<void> _archive(Voluntario v) async {
    final ok = await showConfirmArchiveDialog(
      context: context,
      nombre: '${v.nombre} ${v.apellido}',
      restoring: !v.activo,
    );
    if (!ok) return;
    try {
      if (v.activo) {
        await ApiService.archiveVoluntario(v.voluntarioId);
      } else {
        await ApiService.restoreVoluntario(v.voluntarioId);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _deletePermanente(Voluntario v) async {
    if (v.activo) return;
    final ok = await showConfirmPermanentDeleteDialog(
      context: context,
      nombre: '${v.nombre} ${v.apellido}',
    );
    if (!ok) return;
    try {
      await ApiService.deleteVoluntarioPermanente(v.voluntarioId);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Voluntario'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _voluntario == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _voluntario == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_voluntario == null) {
      return const Center(child: Text('No se encontraron datos.'));
    }

    final voluntario = _voluntario!;
    final aniosTrabajo = voluntario.fechaInicio != null
        ? _calcularAnios(voluntario.fechaInicio!, voluntario.fechaRetiro)
        : 0;
    final isActivo = voluntario.estatus.toLowerCase() == 'activo';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailHeader(
            name: '${voluntario.nombre} ${voluntario.apellido}',
            actions: [
              if (voluntario.activo)
                FilledButton.icon(
                  onPressed: () => _edit(voluntario),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Editar'),
                ),
              OutlinedButton.icon(
                onPressed: () => _archive(voluntario),
                icon: Icon(voluntario.activo ? Icons.archive : Icons.unarchive, size: 18),
                label: Text(voluntario.activo ? 'Archivar' : 'Restaurar'),
              ),
              if (!voluntario.activo)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => _deletePermanente(voluntario),
                  icon: const Icon(Icons.delete_forever, size: 18),
                  label: const Text('Eliminar'),
                ),
            ],
          ),
          DetailSection(
            title: 'Datos personales',
            children: [
              DetailField(label: 'Cédula', value: voluntario.ci),
              DetailField(label: 'Teléfono', value: voluntario.telefono),
              DetailField(label: 'Correo', value: voluntario.email),
              DetailField(label: 'Fecha de nacimiento', value: _formatDate(voluntario.fechaNacimiento)),
              DetailField(label: 'Residencia', value: voluntario.residencia),
              DetailField(label: 'Fecha de inducción', value: _formatDate(voluntario.fechaInduccion)),
            ],
          ),
          DetailSection(
            title: 'Voluntariado',
            trailing: OutlinedButton(
              onPressed: () => _cambiarEstatus(voluntario),
              child: Text(isActivo ? 'Marcar inactivo' : 'Marcar activo'),
            ),
            children: [
              DetailField(
                label: 'Estatus',
                value: voluntario.estatus,
                child: statusChip(voluntario.estatus, archived: !voluntario.activo),
              ),
              DetailField(label: 'Fecha de inicio', value: _formatDate(voluntario.fechaInicio)),
              DetailField(label: 'Fecha de retiro', value: _formatDate(voluntario.fechaRetiro)),
              DetailField(label: 'Años de apoyo', value: '$aniosTrabajo años'),
              DetailField(label: 'Profesión / Oficio', value: voluntario.profesionOficio),
              DetailField(label: 'Lugar de trabajo', value: voluntario.institucion),
              DetailField(label: 'Actividad', value: voluntario.actividad ?? '—'),
              DetailField(
                label: 'Asistencias',
                value: '${voluntario.asistencias ?? 0}',
                child: _AsistenciasRow(
                  value: voluntario.asistencias ?? 0,
                  busy: _savingAsistencias,
                  onDecrement: () => _setAsistencias((voluntario.asistencias ?? 0) - 1),
                  onIncrement: () => _setAsistencias((voluntario.asistencias ?? 0) + 1),
                  onEdit: _editarAsistencias,
                ),
              ),
            ],
          ),
          ObservacionesPanel(
            basePath: '/api/volunteers',
            recordId: voluntario.voluntarioId,
          ),
        ],
      ),
    );
  }
}

class _AsistenciasEditDialog extends StatefulWidget {
  final int initial;

  const _AsistenciasEditDialog({required this.initial});

  @override
  State<_AsistenciasEditDialog> createState() => _AsistenciasEditDialogState();
}

class _AsistenciasEditDialogState extends State<_AsistenciasEditDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initial}');
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Ingresa un número');
      return;
    }
    final n = int.tryParse(raw);
    if (n == null || n < 0) {
      setState(() => _error = 'Número inválido');
      return;
    }
    Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Asistencias'),
      content: SizedBox(
        width: 280,
        child: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: InputDecoration(
            labelText: 'Cantidad',
            border: const OutlineInputBorder(),
            errorText: _error,
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
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

class _AsistenciasRow extends StatelessWidget {
  final int value;
  final bool busy;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onEdit;

  const _AsistenciasRow({
    required this.value,
    required this.busy,
    required this.onDecrement,
    required this.onIncrement,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Text('Asistencias:', style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            IconButton(
              tooltip: 'Restar',
              onPressed: value <= 0 ? null : onDecrement,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            GestureDetector(
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Sumar',
              onPressed: onIncrement,
              icon: const Icon(Icons.add_circle_outline),
            ),
            IconButton(
              tooltip: 'Escribir cantidad',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
          ],
        ],
      ),
    );
  }
}
