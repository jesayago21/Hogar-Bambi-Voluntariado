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

class LaborSocialDetailsScreen extends StatefulWidget {
  final int studentId;

  const LaborSocialDetailsScreen({super.key, required this.studentId});

  @override
  State<LaborSocialDetailsScreen> createState() => _LaborSocialDetailsScreenState();
}

class _LaborSocialDetailsScreenState extends State<LaborSocialDetailsScreen> {
  LaborSocial? _student;
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
      final s = await ApiService.getLaborSocialStudentById(widget.studentId);
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

  String _formatDate(DateTime? date) =>
      date != null ? DateFormat('dd/MM/yyyy').format(date) : '—';

  Future<void> _edit(LaborSocial s) async {
    final data = await showRecordFormDialog(
      context: context,
      title: 'Editar Labor Social',
      fields: [
        FormFieldDesc(key: 'nombre', label: 'Nombre', initialValue: s.persona.nombre, requiredField: true),
        FormFieldDesc(key: 'apellido', label: 'Apellido', initialValue: s.persona.apellido),
        FormFieldDesc(key: 'ci', label: 'CI', initialValue: s.persona.ci),
        FormFieldDesc(key: 'telefono', label: 'Teléfono', initialValue: s.persona.telefono),
        FormFieldDesc(key: 'email', label: 'Email', initialValue: s.persona.email),
        FormFieldDesc(
          key: 'fecha_induccion',
          label: 'Fecha de inducción',
          initialValue: fechaInicialForm(s.persona.fechaInduccion),
          isDate: true,
        ),
        FormFieldDesc(key: 'colegio', label: 'Colegio', initialValue: s.colegio),
        FormFieldDesc(key: 'carrera', label: 'Carrera', initialValue: s.carrera),
        FormFieldDesc(key: 'nivel', label: 'Nivel', initialValue: s.nivel),
        FormFieldDesc(key: 'expediente', label: 'Expediente', initialValue: s.expediente),
        FormFieldDesc(key: 'actividad_apoyo', label: 'Actividad de apoyo', initialValue: s.actividadApoyo),
        FormFieldDesc(key: 'representante', label: 'Representante', initialValue: s.representante),
        FormFieldDesc(
          key: 'telefono_representante',
          label: 'Teléfono representante',
          initialValue: s.telefonoRepresentante,
        ),
        FormFieldDesc(
          key: 'email_representante',
          label: 'Email representante',
          initialValue: s.emailRepresentante,
        ),
        FormFieldDesc(key: 'estatus', label: 'Estatus', initialValue: s.estatus),
        FormFieldDesc(key: 'anio', label: 'Año', initialValue: s.anio?.toString(), keyboardType: TextInputType.number),
        FormFieldDesc(key: 'fecha_inicio', label: 'Fecha de inicio', initialValue: fechaInicialForm(s.fechaInicio), isDate: true),
        FormFieldDesc(
          key: 'fecha_culminacion',
          label: 'Fecha de culminación',
          initialValue: fechaInicialForm(s.fechaCulminacion),
          isDate: true,
        ),
        FormFieldDesc(
          key: 'fecha_carta_culminacion',
          label: 'Carta culminación digital',
          initialValue: fechaInicialForm(s.fechaCartaCulminacion),
          isDate: true,
        ),
      ],
    );
    if (data == null) return;
    try {
      await ApiService.updateLaborSocial(s.id, buildApiBody(data));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _archive(LaborSocial s) async {
    final ok = await showConfirmArchiveDialog(
      context: context,
      nombre: '${s.persona.nombre} ${s.persona.apellido}',
      restoring: !s.activo,
    );
    if (!ok) return;
    try {
      if (s.activo) {
        await ApiService.archiveLaborSocial(s.id);
      } else {
        await ApiService.restoreLaborSocial(s.id);
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
        title: const Text('Detalle Labor Social'),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));
    if (_student == null) return const Center(child: Text('No se encontraron datos.'));

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
              DetailField(label: 'Inducción', value: _formatDate(s.persona.fechaInduccion)),
            ],
          ),
          DetailSection(
            title: 'Labor Social',
            children: [
              DetailField(label: 'Colegio', value: s.colegio),
              DetailField(label: 'Carrera', value: s.carrera ?? '—'),
              DetailField(label: 'Expediente', value: s.expediente ?? '—'),
              DetailField(label: 'Actividad de apoyo', value: s.actividadApoyo ?? '—'),
              DetailField(label: 'Nivel', value: s.nivel),
              DetailField(label: 'Año', value: '${s.anio ?? '—'}'),
              DetailField(
                label: 'Estatus',
                value: s.estatus ?? '—',
                child: statusChip(s.estatus, archived: !s.activo),
              ),
              DetailField(label: 'Fecha de inicio', value: _formatDate(s.fechaInicio)),
              DetailField(label: 'Fecha de culminación', value: _formatDate(s.fechaCulminacion)),
              DetailField(
                label: 'Carta culminación digital',
                value: _formatDate(s.fechaCartaCulminacion),
              ),
            ],
          ),
          DetailSection(
            title: 'Representante',
            children: [
              DetailField(label: 'Nombre', value: s.representante ?? '—'),
              DetailField(label: 'Teléfono', value: s.telefonoRepresentante ?? '—'),
              DetailField(label: 'Correo', value: s.emailRepresentante ?? '—'),
            ],
          ),
          ObservacionesPanel(basePath: '/api/students/labor_social', recordId: s.id),
        ],
      ),
    );
  }
}
