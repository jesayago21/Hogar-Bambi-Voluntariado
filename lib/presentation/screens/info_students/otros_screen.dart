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

class OtrosListScreen extends StatefulWidget {
  const OtrosListScreen({super.key});

  @override
  State<OtrosListScreen> createState() => _OtrosListScreenState();
}

class _OtrosListScreenState extends State<OtrosListScreen> {
  List<Otros> _all = [];
  final TextEditingController _searchController = TextEditingController();
  bool _soloArchivados = false;
  String? _tipoFiltro;
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
      final list = await ApiService.getAllOtrosStudents(
        soloArchivados: _soloArchivados,
        tipoActividad: _tipoFiltro,
      );
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

  List<Otros> get _visible => _all.where((o) {
        final p = o.persona;
        return matchesPersonaSearch(
          _searchController.text,
          nombre: p.nombre,
          apellido: p.apellido,
          ci: p.ci,
          email: p.email,
          institucion: o.institucion,
          fechaInicio: o.fechaInicio,
        );
      }).toList();

  List<FormFieldDesc> _fields([Otros? o]) => [
        FormFieldDesc(key: 'nombre', label: 'Nombre', initialValue: o?.persona.nombre, requiredField: true),
        FormFieldDesc(key: 'apellido', label: 'Apellido', initialValue: o?.persona.apellido),
        FormFieldDesc(key: 'ci', label: 'CI', initialValue: o?.persona.ci),
        FormFieldDesc(key: 'telefono', label: 'Teléfono', initialValue: o?.persona.telefono),
        FormFieldDesc(key: 'email', label: 'Email', initialValue: o?.persona.email),
        FormFieldDesc(key: 'tipo_actividad', label: 'Tipo de actividad', initialValue: o?.tipoActividad ?? 'Postgrado'),
        FormFieldDesc(key: 'institucion', label: 'Institución', initialValue: o?.institucion),
        FormFieldDesc(key: 'carrera', label: 'Carrera', initialValue: o?.carrera),
        FormFieldDesc(key: 'estatus', label: 'Estatus', initialValue: o?.estatus),
        FormFieldDesc(key: 'anio', label: 'Año', initialValue: o?.anio?.toString()),
        FormFieldDesc(key: 'fecha_inicio', label: 'Fecha de inicio', initialValue: fechaInicialForm(o?.fechaInicio), isDate: true),
      ];

  Future<void> _create() async {
    final data = await showRecordFormDialog(context: context, title: 'Nuevo registro (Otros)', fields: _fields());
    if (data == null) return;
    try {
      await ApiService.createOtros(buildApiBody(data));
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _edit(Otros o) async {
    final data = await showRecordFormDialog(context: context, title: 'Editar', fields: _fields(o));
    if (data == null) return;
    try {
      await ApiService.updateOtros(o.id, buildApiBody(data));
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _archive(Otros o) async {
    final ok = await showConfirmArchiveDialog(context: context, nombre: '${o.persona.nombre} ${o.persona.apellido}', restoring: !o.activo);
    if (!ok) return;
    try {
      if (o.activo) {
        await ApiService.archiveOtros(o.id);
      } else {
        await ApiService.restoreOtros(o.id);
      }
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _deletePermanente(Otros o) async {
    if (o.activo) return;
    final ok = await showConfirmPermanentDeleteDialog(context: context, nombre: '${o.persona.nombre} ${o.persona.apellido}');
    if (!ok) return;
    try {
      await ApiService.deleteOtrosPermanente(o.id);
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  List<PopupMenuEntry<String>> _menuItems(Otros o) => [
        if (o.activo) const PopupMenuItem(value: 'edit', child: Text('Editar')),
        PopupMenuItem(value: 'archive', child: Text(o.activo ? 'Archivar' : 'Restaurar')),
        if (!o.activo) const PopupMenuItem(value: 'delete', child: Text('Eliminar definitivamente')),
      ];

  void _onMenu(Otros o, String a) {
    if (a == 'edit') _edit(o);
    if (a == 'archive') _archive(o);
    if (a == 'delete') _deletePermanente(o);
  }

  Future<void> _importExcel() async {
    final ok = await showImportExcelDialog(
      context: context,
      titulo: 'Otros',
      modulePath: '/api/others',
      nombrePlantilla: 'plantilla_otros.xlsx',
    );
    if (ok == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Otros / Postgrado'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Filtrar tipo',
            onSelected: (v) {
              _tipoFiltro = v.isEmpty ? null : v;
              _reload();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: '', child: Text('Todos')),
              PopupMenuItem(value: 'Postgrado', child: Text('Solo Postgrado')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.filter_list),
                  const SizedBox(width: 4),
                  Text(_tipoFiltro ?? 'Todos', style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          ModuleListToolbar(
            searchController: _searchController,
            searchHint: 'Buscar por nombre, CI, correo, institución o fecha...',
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
                        ? const Center(child: Text('No hay registros disponibles.'))
                        : DataTableList<Otros>(
                            items: visible,
                            onRowTap: (o) => context.push('/others/${o.id}'),
                            columns: [
                              TableColumnSpec(label: 'Nombre y apellido', minWidth: 180, flex: 2, value: (o) => '${o.persona.nombre} ${o.persona.apellido}'),
                              TableColumnSpec(label: 'Cédula', minWidth: 100, value: (o) => dash(o.persona.ci)),
                              TableColumnSpec(label: 'Teléfono', minWidth: 110, value: (o) => dash(o.persona.telefono)),
                              TableColumnSpec(label: 'Correo', minWidth: 160, flex: 2, value: (o) => dash(o.persona.email)),
                              TableColumnSpec(label: 'Tipo', minWidth: 100, value: (o) => dash(o.tipoActividad)),
                              TableColumnSpec(label: 'Institución', minWidth: 120, flex: 1, value: (o) => dash(o.institucion)),
                              TableColumnSpec(label: 'Carrera', minWidth: 110, value: (o) => dash(o.carrera)),
                              TableColumnSpec(label: 'Estatus', minWidth: 90, value: (o) => o.estatus ?? '—', cell: (o) => statusChip(o.estatus, archived: !o.activo)),
                              TableColumnSpec(label: 'Fecha inicio', minWidth: 100, value: (o) => formatFechaCorta(o.fechaInicio)),
                            ],
                            actionsBuilder: (o) => tableActions(
                              onView: () => context.push('/others/${o.id}'),
                              menuItems: _menuItems(o),
                              onMenuSelected: (a) => _onMenu(o, a),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
