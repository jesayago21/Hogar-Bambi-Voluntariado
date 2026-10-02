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

class VolunteersScreen extends StatefulWidget {
  static const String name = 'volunteers_screen';

  const VolunteersScreen({super.key});

  @override
  State<VolunteersScreen> createState() => _VolunteersScreenState();
}

class _VolunteersScreenState extends State<VolunteersScreen> {
  List<Voluntario> _all = [];
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
      final list = await ApiService.getVoluntarios(soloArchivados: _soloArchivados);
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

  List<Voluntario> get _visible {
    final q = _searchController.text;
    return _all
        .where(
          (v) => matchesPersonaSearch(
            q,
            nombre: v.nombre,
            apellido: v.apellido,
            ci: v.ci,
            email: v.email,
            fechaInicio: v.fechaInicio,
          ),
        )
        .toList();
  }

  List<FormFieldDesc> _fields({Voluntario? v, bool forCreate = false}) => [
        FormFieldDesc(key: 'nombre', label: 'Nombre', initialValue: v?.nombre, requiredField: true),
        FormFieldDesc(key: 'apellido', label: 'Apellido', initialValue: v?.apellido),
        FormFieldDesc(key: 'ci', label: 'CI', initialValue: v?.ci),
        FormFieldDesc(key: 'telefono', label: 'Teléfono', initialValue: v?.telefono),
        FormFieldDesc(key: 'email', label: 'Email', initialValue: v?.email),
        FormFieldDesc(key: 'residencia', label: 'Residencia', initialValue: v?.residencia),
        FormFieldDesc(key: 'profesion_oficio', label: 'Profesión/Oficio', initialValue: v?.profesionOficio),
        FormFieldDesc(key: 'lugar_trabajo', label: 'Lugar de trabajo', initialValue: v?.institucion),
        FormFieldDesc(key: 'actividad', label: 'Actividad', initialValue: v?.actividad),
        FormFieldDesc(
          key: 'fecha_inicio',
          label: 'Fecha de inicio',
          initialValue: fechaInicialForm(v?.fechaInicio),
          isDate: true,
        ),
        FormFieldDesc(
          key: 'fecha_induccion',
          label: 'Fecha de inducción',
          initialValue: fechaInicialForm(v?.fechaInduccion),
          isDate: true,
        ),
      ];

  Map<String, dynamic> _bodyFrom(Map<String, String> m, {bool forCreate = false}) {
    final body = buildApiBody(m);
    if (forCreate) body['estatus'] = 'Activo';
    return body;
  }

  Future<void> _create() async {
    final data = await showRecordFormDialog(
      context: context,
      title: 'Nuevo voluntario',
      fields: _fields(forCreate: true),
    );
    if (data == null) return;
    try {
      await ApiService.createVoluntario(_bodyFrom(data, forCreate: true));
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _edit(Voluntario v) async {
    final data = await showRecordFormDialog(
      context: context,
      title: 'Editar voluntario',
      fields: _fields(v: v),
    );
    if (data == null) return;
    try {
      await ApiService.updateVoluntario(v.voluntarioId, _bodyFrom(data));
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _archiveOrRestore(Voluntario v) async {
    final restoring = !v.activo;
    final ok = await showConfirmArchiveDialog(
      context: context,
      nombre: '${v.nombre} ${v.apellido}',
      restoring: restoring,
    );
    if (!ok) return;
    try {
      if (restoring) {
        await ApiService.restoreVoluntario(v.voluntarioId);
      } else {
        await ApiService.archiveVoluntario(v.voluntarioId);
      }
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  List<PopupMenuEntry<String>> _menuItems(Voluntario v) => [
        if (v.activo) const PopupMenuItem(value: 'edit', child: Text('Editar')),
        PopupMenuItem(
          value: 'archive',
          child: Text(v.activo ? 'Archivar' : 'Restaurar'),
        ),
        if (!v.activo)
          const PopupMenuItem(value: 'delete', child: Text('Eliminar definitivamente')),
      ];

  void _onMenu(Voluntario v, String action) {
    if (action == 'edit') _edit(v);
    if (action == 'archive') _archiveOrRestore(v);
    if (action == 'delete') _deletePermanente(v);
  }

  Future<void> _importExcel() async {
    final ok = await showImportExcelDialog(
      context: context,
      titulo: 'Voluntarios',
      modulePath: '/api/volunteers',
      nombrePlantilla: 'plantilla_voluntarios.xlsx',
    );
    if (ok == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voluntarios'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/system'),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ModuleListToolbar(
            searchController: _searchController,
            searchHint: 'Buscar por nombre, CI, correo o fecha...',
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
                        ? Center(
                            child: Text(
                              _soloArchivados
                                  ? 'No hay voluntarios archivados.'
                                  : 'No hay voluntarios disponibles.',
                            ),
                          )
                        : DataTableList<Voluntario>(
                            items: visible,
                            onRowTap: (v) => context.push('/volunteer/details/${v.voluntarioId}'),
                            columns: [
                              TableColumnSpec<Voluntario>(
                                label: 'Nombre y apellido',
                                minWidth: 180,
                                flex: 2,
                                value: (v) => '${v.nombre} ${v.apellido}',
                              ),
                              TableColumnSpec(
                                label: 'Cédula',
                                minWidth: 100,
                                value: (v) => dash(v.ci),
                              ),
                              TableColumnSpec(
                                label: 'Teléfono',
                                minWidth: 110,
                                value: (v) => dash(v.telefono),
                              ),
                              TableColumnSpec(
                                label: 'Correo',
                                minWidth: 160,
                                flex: 2,
                                value: (v) => dash(v.email),
                              ),
                              TableColumnSpec(
                                label: 'Estatus',
                                minWidth: 90,
                                value: (v) => v.estatus,
                                cell: (v) => statusChip(v.estatus, archived: !v.activo),
                              ),
                              TableColumnSpec(
                                label: 'Fecha inicio',
                                minWidth: 100,
                                value: (v) => formatFechaCorta(v.fechaInicio),
                              ),
                              TableColumnSpec(
                                label: 'Actividad',
                                minWidth: 140,
                                flex: 2,
                                value: (v) => dash(v.actividad),
                              ),
                            ],
                            actionsBuilder: (v) => tableActions(
                              onView: () => context.push('/volunteer/details/${v.voluntarioId}'),
                              menuItems: _menuItems(v),
                              onMenuSelected: (a) => _onMenu(v, a),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
