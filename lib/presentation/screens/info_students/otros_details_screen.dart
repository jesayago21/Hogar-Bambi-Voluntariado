import 'package:flutter/material.dart';
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

class OtrosDetailsScreen extends StatefulWidget {
  final int studentId;

  const OtrosDetailsScreen({super.key, required this.studentId});

  @override
  State<OtrosDetailsScreen> createState() => _OtrosDetailsScreenState();
}

class _OtrosDetailsScreenState extends State<OtrosDetailsScreen> {
  Otros? _record;
  bool _loading = true;
  Object? _error;

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
      final o = await ApiService.getOtrosStudentById(widget.studentId);
      if (!mounted) return;
      setState(() {
        _record = o;
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

  String _fmt(DateTime? d) => d != null ? DateFormat('dd/MM/yyyy').format(d) : '—';

  Future<void> _edit(Otros o) async {
    final data = await showRecordFormDialog(
      context: context,
      title: 'Editar',
      fields: [
        FormFieldDesc(key: 'nombre', label: 'Nombre', initialValue: o.persona.nombre, requiredField: true),
        FormFieldDesc(key: 'apellido', label: 'Apellido', initialValue: o.persona.apellido),
        FormFieldDesc(key: 'ci', label: 'CI', initialValue: o.persona.ci),
        FormFieldDesc(key: 'telefono', label: 'Teléfono', initialValue: o.persona.telefono),
        FormFieldDesc(key: 'email', label: 'Email', initialValue: o.persona.email),
        FormFieldDesc(key: 'tipo_actividad', label: 'Tipo actividad', initialValue: o.tipoActividad),
        FormFieldDesc(key: 'institucion', label: 'Institución', initialValue: o.institucion),
        FormFieldDesc(key: 'carrera', label: 'Carrera', initialValue: o.carrera),
        FormFieldDesc(key: 'estatus', label: 'Estatus', initialValue: o.estatus),
        FormFieldDesc(key: 'anio', label: 'Año', initialValue: o.anio?.toString(), keyboardType: TextInputType.number),
        FormFieldDesc(key: 'fecha_inicio', label: 'Fecha de inicio', initialValue: fechaInicialForm(o.fechaInicio), isDate: true),
        FormFieldDesc(key: 'fecha_culminacion', label: 'Fecha de culminación', initialValue: fechaInicialForm(o.fechaCulminacion), isDate: true),
      ],
    );
    if (data == null) return;
    try {
      await ApiService.updateOtros(o.id, buildApiBody(data));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _archive(Otros o) async {
    final ok = await showConfirmArchiveDialog(
      context: context,
      nombre: '${o.persona.nombre} ${o.persona.apellido}',
      restoring: !o.activo,
    );
    if (!ok) return;
    try {
      if (o.activo) {
        await ApiService.archiveOtros(o.id);
      } else {
        await ApiService.restoreOtros(o.id);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle Otros'),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));
    if (_record == null) return const Center(child: Text('Sin datos'));

    final o = _record!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailHeader(
            name: '${o.persona.nombre} ${o.persona.apellido}',
            actions: [
              if (o.activo)
                FilledButton.icon(
                  onPressed: () => _edit(o),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Editar'),
                ),
              OutlinedButton.icon(
                onPressed: () => _archive(o),
                icon: Icon(o.activo ? Icons.archive : Icons.unarchive, size: 18),
                label: Text(o.activo ? 'Archivar' : 'Restaurar'),
              ),
            ],
          ),
          DetailSection(
            title: 'Datos personales',
            children: [
              DetailField(label: 'Cédula', value: o.persona.ci),
              DetailField(label: 'Teléfono', value: o.persona.telefono),
              DetailField(label: 'Correo', value: o.persona.email),
              DetailField(label: 'Inducción', value: _fmt(o.persona.fechaInduccion)),
            ],
          ),
          DetailSection(
            title: 'Otros / Postgrado',
            children: [
              DetailField(label: 'Tipo de actividad', value: o.tipoActividad),
              DetailField(label: 'Institución', value: o.institucion),
              DetailField(label: 'Carrera', value: o.carrera ?? '—'),
              DetailField(label: 'Año', value: '${o.anio ?? '—'}'),
              DetailField(
                label: 'Estatus',
                value: o.estatus ?? '—',
                child: statusChip(o.estatus, archived: !o.activo),
              ),
              DetailField(label: 'Fecha de inicio', value: _fmt(o.fechaInicio)),
              DetailField(label: 'Fecha de culminación', value: _fmt(o.fechaCulminacion)),
            ],
          ),
          ObservacionesPanel(basePath: '/api/others', recordId: o.id),
        ],
      ),
    );
  }
}
