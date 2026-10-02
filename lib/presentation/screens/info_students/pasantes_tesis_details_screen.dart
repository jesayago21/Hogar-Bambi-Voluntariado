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

class InternshipThesisProjectDetailsScreen extends StatefulWidget {
  final int studentId;

  const InternshipThesisProjectDetailsScreen({super.key, required this.studentId});

  @override
  State<InternshipThesisProjectDetailsScreen> createState() =>
      _InternshipThesisProjectDetailsScreenState();
}

class _InternshipThesisProjectDetailsScreenState extends State<InternshipThesisProjectDetailsScreen> {
  PasantiaTesisProyecto? _student;
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
      final s = await ApiService.getInternshipThesisProjectStudentById(widget.studentId);
      if (!mounted) return;
      setState(() {
        _student = s;
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

  Future<void> _edit(PasantiaTesisProyecto s) async {
    final data = await showRecordFormDialog(
      context: context,
      title: 'Editar',
      fields: [
        FormFieldDesc(key: 'nombre', label: 'Nombre', initialValue: s.persona.nombre, requiredField: true),
        FormFieldDesc(key: 'apellido', label: 'Apellido', initialValue: s.persona.apellido),
        FormFieldDesc(key: 'ci', label: 'CI', initialValue: s.persona.ci),
        FormFieldDesc(key: 'telefono', label: 'Teléfono', initialValue: s.persona.telefono),
        FormFieldDesc(key: 'email', label: 'Email', initialValue: s.persona.email),
        FormFieldDesc(key: 'tipo', label: 'Tipo', initialValue: s.tipo),
        FormFieldDesc(key: 'instituto', label: 'Instituto', initialValue: s.instituto),
        FormFieldDesc(key: 'carrera', label: 'Carrera', initialValue: s.carrera),
        FormFieldDesc(key: 'tutor_academico', label: 'Tutor académico', initialValue: s.tutorAcademico),
        FormFieldDesc(key: 'tutor_institucional', label: 'Tutor institucional', initialValue: s.tutorInstitucional),
        FormFieldDesc(key: 'estatus', label: 'Estatus', initialValue: s.estatus),
        FormFieldDesc(key: 'anio', label: 'Año', initialValue: s.anio?.toString(), keyboardType: TextInputType.number),
        FormFieldDesc(key: 'fecha_inicio', label: 'Fecha de inicio', initialValue: fechaInicialForm(s.fechaInicio), isDate: true),
        FormFieldDesc(key: 'fecha_culminacion', label: 'Fecha de culminación', initialValue: fechaInicialForm(s.fechaCulminacion), isDate: true),
      ],
    );
    if (data == null) return;
    try {
      await ApiService.updateInternship(s.id, buildApiBody(data));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _archive(PasantiaTesisProyecto s) async {
    final ok = await showConfirmArchiveDialog(
      context: context,
      nombre: '${s.persona.nombre} ${s.persona.apellido}',
      restoring: !s.activo,
    );
    if (!ok) return;
    try {
      if (s.activo) {
        await ApiService.archiveInternship(s.id);
      } else {
        await ApiService.restoreInternship(s.id);
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
        title: const Text('Detalle Pasantía/Tesis/Proyecto'),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));
    if (_student == null) return const Center(child: Text('Sin datos'));

    final s = _student!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailHeader(
            name: '${s.persona.nombre} ${s.persona.apellido}',
            actions: [
              if (s.activo)
                FilledButton.icon(
                  onPressed: () => _edit(s),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Editar'),
                ),
              OutlinedButton.icon(
                onPressed: () => _archive(s),
                icon: Icon(s.activo ? Icons.archive : Icons.unarchive, size: 18),
                label: Text(s.activo ? 'Archivar' : 'Restaurar'),
              ),
            ],
          ),
          DetailSection(
            title: 'Datos personales',
            children: [
              DetailField(label: 'Cédula', value: s.persona.ci),
              DetailField(label: 'Teléfono', value: s.persona.telefono),
              DetailField(label: 'Correo', value: s.persona.email),
              DetailField(label: 'Inducción', value: _fmt(s.persona.fechaInduccion)),
            ],
          ),
          DetailSection(
            title: 'Pasantía / Tesis / Proyecto',
            children: [
              DetailField(label: 'Tipo', value: s.tipo),
              DetailField(label: 'Instituto', value: s.instituto),
              DetailField(label: 'Carrera', value: s.carrera),
              DetailField(label: 'Tutor académico', value: s.tutorAcademico),
              DetailField(label: 'Tutor institucional', value: s.tutorInstitucional),
              DetailField(label: 'Año', value: '${s.anio ?? '—'}'),
              DetailField(
                label: 'Estatus',
                value: s.estatus ?? '—',
                child: statusChip(s.estatus, archived: !s.activo),
              ),
              DetailField(label: 'Fecha de inicio', value: _fmt(s.fechaInicio)),
              DetailField(label: 'Fecha de culminación', value: _fmt(s.fechaCulminacion)),
            ],
          ),
          ObservacionesPanel(basePath: '/api/students/internship_thesis_project', recordId: s.id),
        ],
      ),
    );
  }
}
