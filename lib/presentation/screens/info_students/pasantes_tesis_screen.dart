import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:voluntariado_desktop_app/domain/volunteer/entities/volunteer.dart';
import 'package:voluntariado_desktop_app/infraestructure/datasources/api_volunteer_datasource_dart.dart';
import 'package:voluntariado_desktop_app/presentation/utils/date_search.dart';
import 'package:voluntariado_desktop_app/presentation/utils/form_body.dart';
import 'package:voluntariado_desktop_app/presentation/widgets/confirm_archive_dialog.dart';
import 'package:voluntariado_desktop_app/presentation/widgets/data_table_list.dart';
import 'package:voluntariado_desktop_app/presentation/widgets/import_excel_dialog.dart';
import 'package:voluntariado_desktop_app/presentation/widgets/record_form_dialog.dart';

class InternshipThesisProjectScreen extends StatefulWidget {
  const InternshipThesisProjectScreen({super.key});

  @override
  State<InternshipThesisProjectScreen> createState() => _InternshipThesisProjectScreenState();
}

class _InternshipThesisProjectScreenState extends State<InternshipThesisProjectScreen> {
  List<PasantiaTesisProyecto> _all = [];
  final TextEditingController _searchController = TextEditingController();
  bool _soloArchivados = false;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.getInternshipThesisProjectStudents(soloArchivados: _soloArchivados);
      if (!mounted) return;
      setState(() {
        _all = list;
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

  List<PasantiaTesisProyecto> get _visible => _all.where((s) {
        final p = s.persona;
        return matchesPersonaSearch(
          _searchController.text,
          nombre: p.nombre,
          apellido: p.apellido,
          ci: p.ci,
          email: p.email,
          institucion: s.instituto,
          fechaInicio: s.fechaInicio,
        );
      }).toList();

  List<FormFieldDesc> _fields([PasantiaTesisProyecto? s]) => [
        FormFieldDesc(key: 'nombre', label: 'Nombre', initialValue: s?.persona.nombre, requiredField: true),
        FormFieldDesc(key: 'apellido', label: 'Apellido', initialValue: s?.persona.apellido),
        FormFieldDesc(key: 'ci', label: 'CI', initialValue: s?.persona.ci),
        FormFieldDesc(key: 'telefono', label: 'Teléfono', initialValue: s?.persona.telefono),
        FormFieldDesc(key: 'email', label: 'Email', initialValue: s?.persona.email),
        FormFieldDesc(key: 'tipo', label: 'Tipo', initialValue: s?.tipo ?? 'pasantia'),
        FormFieldDesc(key: 'instituto', label: 'Instituto', initialValue: s?.instituto),
        FormFieldDesc(key: 'carrera', label: 'Carrera', initialValue: s?.carrera),
        FormFieldDesc(key: 'tutor_academico', label: 'Tutor académico', initialValue: s?.tutorAcademico),
        FormFieldDesc(key: 'tutor_institucional', label: 'Tutor institucional', initialValue: s?.tutorInstitucional),
        FormFieldDesc(key: 'estatus', label: 'Estatus', initialValue: s?.estatus),
        FormFieldDesc(key: 'anio', label: 'Año', initialValue: s?.anio?.toString()),
        FormFieldDesc(key: 'fecha_inicio', label: 'Fecha de inicio', initialValue: fechaInicialForm(s?.fechaInicio), isDate: true),
      ];

  Future<void> _create() async {
    final data = await showRecordFormDialog(context: context, title: 'Nueva pasantía/tesis/proyecto', fields: _fields());
    if (data == null) return;
    try {
      await ApiService.createInternship(buildApiBody(data));
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _edit(PasantiaTesisProyecto s) async {
    final data = await showRecordFormDialog(context: context, title: 'Editar', fields: _fields(s));
    if (data == null) return;
    try {
      await ApiService.updateInternship(s.id, buildApiBody(data));
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _archive(PasantiaTesisProyecto s) async {
    final ok = await showConfirmArchiveDialog(context: context, nombre: '${s.persona.nombre} ${s.persona.apellido}', restoring: !s.activo);
    if (!ok) return;
    try {
      if (s.activo) {
        await ApiService.archiveInternship(s.id);
      } else {
        await ApiService.restoreInternship(s.id);
      }
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _deletePermanente(PasantiaTesisProyecto s) async {
    if (s.activo) return;
    final ok = await showConfirmPermanentDeleteDialog(context: context, nombre: '${s.persona.nombre} ${s.persona.apellido}');
    if (!ok) return;
    try {
      await ApiService.deleteInternshipPermanente(s.id);
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  List<PopupMenuEntry<String>> _menuItems(PasantiaTesisProyecto s) => [
        if (s.activo) const PopupMenuItem(value: 'edit', child: Text('Editar')),
        PopupMenuItem(value: 'archive', child: Text(s.activo ? 'Archivar' : 'Restaurar')),
        if (!s.activo) const PopupMenuItem(value: 'delete', child: Text('Eliminar definitivamente')),
      ];

  void _onMenu(PasantiaTesisProyecto s, String a) {
    if (a == 'edit') _edit(s);
    if (a == 'archive') _archive(s);
    if (a == 'delete') _deletePermanente(s);
  }

  Future<void> _importExcel() async {
    final ok = await showImportExcelDialog(
      context: context,
      titulo: 'Pasantías',
      modulePath: '/api/students/internship_thesis_project',
      nombrePlantilla: 'plantilla_pasantias.xlsx',
    );
    if (ok == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pasantías, Tesis y Proyectos'),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
      ),
      body: Column(
        children: [
          ModuleListToolbar(
            searchController: _searchController,
            searchHint: 'Buscar por nombre, CI, correo, instituto o fecha...',
            soloArchivados: _soloArchivados,
            onArchivadosChanged: (v) {
              _soloArchivados = v;
              _reload();
            },
            totalCount: _all.length,
            filteredCount: visible.length,
            onCreate: _create,
            onImport: _importExcel,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : _all.isEmpty
                        ? const Center(child: Text('No hay estudiantes registrados.'))
                        : DataTableList<PasantiaTesisProyecto>(
                            items: visible,
                            onRowTap: (s) => context.push('/students/internship/${s.id}'),
                            columns: [
                              TableColumnSpec(label: 'Nombre y apellido', minWidth: 180, flex: 2, value: (s) => '${s.persona.nombre} ${s.persona.apellido}'),
                              TableColumnSpec(label: 'Cédula', minWidth: 100, value: (s) => dash(s.persona.ci)),
                              TableColumnSpec(label: 'Teléfono', minWidth: 110, value: (s) => dash(s.persona.telefono)),
                              TableColumnSpec(label: 'Correo', minWidth: 160, flex: 2, value: (s) => dash(s.persona.email)),
                              TableColumnSpec(label: 'Tipo', minWidth: 90, value: (s) => dash(s.tipo)),
                              TableColumnSpec(label: 'Instituto', minWidth: 120, flex: 1, value: (s) => dash(s.instituto)),
                              TableColumnSpec(label: 'Carrera', minWidth: 110, value: (s) => dash(s.carrera)),
                              TableColumnSpec(label: 'Estatus', minWidth: 90, value: (s) => s.estatus ?? '—', cell: (s) => statusChip(s.estatus, archived: !s.activo)),
                              TableColumnSpec(label: 'Fecha inicio', minWidth: 100, value: (s) => formatFechaCorta(s.fechaInicio)),
                            ],
                            actionsBuilder: (s) => tableActions(
                              onView: () => context.push('/students/internship/${s.id}'),
                              menuItems: _menuItems(s),
                              onMenuSelected: (a) => _onMenu(s, a),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
