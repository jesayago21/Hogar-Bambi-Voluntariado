import 'package:flutter/material.dart';

class TableColumnSpec<T> {
  final String label;
  final double minWidth;
  final int flex;
  final String Function(T item) value;
  final Widget Function(T item)? cell;
  final Alignment align;

  const TableColumnSpec({
    required this.label,
    this.minWidth = 100,
    this.flex = 1,
    required this.value,
    this.cell,
    this.align = Alignment.centerLeft,
  });
}

/// Barra compacta: búsqueda, switch archivados, contador y botón nuevo.
class ModuleListToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchHint;
  final bool soloArchivados;
  final ValueChanged<bool> onArchivadosChanged;
  final int totalCount;
  final int filteredCount;
  final VoidCallback onCreate;
  final VoidCallback? onImport;
  final List<Widget>? extraActions;

  const ModuleListToolbar({
    super.key,
    required this.searchController,
    required this.searchHint,
    required this.soloArchivados,
    required this.onArchivadosChanged,
    required this.totalCount,
    required this.filteredCount,
    required this.onCreate,
    this.onImport,
    this.extraActions,
  });

  Widget? get _importButton {
    if (onImport == null) return null;
    return OutlinedButton.icon(
      onPressed: onImport,
      icon: const Icon(Icons.upload_file, size: 18),
      label: const Text('Importar Excel'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showing = filteredCount != totalCount
        ? '$filteredCount de $totalCount registros'
        : '$totalCount registros';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 720;
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: searchHint,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Solo archivados', style: TextStyle(fontSize: 13)),
                        Switch(
                          value: soloArchivados,
                          onChanged: onArchivadosChanged,
                        ),
                      ],
                    ),
                    if (extraActions != null) ...extraActions!,
                    Text(showing, style: Theme.of(context).textTheme.bodySmall),
                    if (_importButton != null) _importButton!,
                    FilledButton.icon(
                      onPressed: onCreate,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nuevo'),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: searchHint,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Solo archivados', style: TextStyle(fontSize: 13)),
                  Switch(
                    value: soloArchivados,
                    onChanged: onArchivadosChanged,
                  ),
                ],
              ),
              if (extraActions != null) ...extraActions!,
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  showing,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (_importButton != null) ...[
                _importButton!,
                const SizedBox(width: 8),
              ],
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Tabla virtualizada con encabezado fijo y scroll horizontal compartido.
class DataTableList<T> extends StatelessWidget {
  final List<T> items;
  final List<TableColumnSpec<T>> columns;
  final double rowHeight;
  final void Function(T item) onRowTap;
  final Widget Function(T item)? actionsBuilder;

  const DataTableList({
    super.key,
    required this.items,
    required this.columns,
    required this.onRowTap,
    this.actionsBuilder,
    this.rowHeight = 44,
  });

  static const double _actionsWidth = 88;

  List<double> _columnWidths(double available) {
    if (columns.isEmpty) return const [];

    final widths = columns.map((c) => c.minWidth).toList();
    final minTotal = widths.fold<double>(0, (s, w) => s + w);

    if (available <= minTotal) return widths;

    var extra = available - minTotal;
    final totalFlex = columns.fold<int>(0, (s, c) => s + c.flex);
    if (totalFlex <= 0) return widths;

    for (var i = 0; i < columns.length; i++) {
      widths[i] += extra * columns[i].flex / totalFlex;
    }
    return widths;
  }

  double _tableMinWidth() {
    return columns.fold<double>(0, (s, c) => s + c.minWidth) +
        (actionsBuilder != null ? _actionsWidth : 0);
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Sin resultados.'));
    }

    final theme = Theme.of(context);
    final borderColor = theme.dividerColor.withValues(alpha: 0.6);
    final headerBg = theme.colorScheme.surfaceContainerHighest;

    return LayoutBuilder(
      builder: (context, constraints) {
        final minW = _tableMinWidth();
        final tableWidth = constraints.maxWidth > minW ? constraints.maxWidth : minW;
        final tableHeight = constraints.maxHeight;
        final colWidths = _columnWidths(
          tableWidth - (actionsBuilder != null ? _actionsWidth : 0),
        );

        Widget buildHeader() {
          return Container(
            height: 40,
            color: headerBg,
            child: Row(
              children: [
                for (var i = 0; i < columns.length; i++)
                  SizedBox(
                    width: colWidths[i],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Align(
                        alignment: columns[i].align,
                        child: Text(
                          columns[i].label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                if (actionsBuilder != null)
                  const SizedBox(
                    width: _actionsWidth,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Acciones',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        Widget buildRow(T item, int index) {
          final bg = index.isOdd
              ? theme.colorScheme.surface.withValues(alpha: 0.5)
              : theme.colorScheme.surface;

          return Material(
            color: bg,
            child: InkWell(
              onTap: () => onRowTap(item),
              hoverColor: theme.colorScheme.primary.withValues(alpha: 0.06),
              child: Container(
                height: rowHeight,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < columns.length; i++)
                      SizedBox(
                        width: colWidths[i],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Align(
                            alignment: columns[i].align,
                            widthFactor: 1,
                            child: colWidths[i] > 16
                                ? (columns[i].cell != null
                                    ? columns[i].cell!(item)
                                    : Tooltip(
                                        message: columns[i].value(item),
                                        child: Text(
                                          columns[i].value(item),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ))
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    if (actionsBuilder != null)
                      SizedBox(
                        width: _actionsWidth,
                        child: actionsBuilder!(item),
                      ),
                  ],
                ),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            height: tableHeight,
            child: Column(
              children: [
                buildHeader(),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemExtent: rowHeight,
                    itemBuilder: (context, index) => buildRow(items[index], index),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget statusChip(String? estatus, {bool archived = false}) {
  final text = estatus?.trim().isNotEmpty == true ? estatus! : '—';
  Color bg;
  Color fg;

  if (archived) {
    bg = Colors.grey.shade300;
    fg = Colors.grey.shade800;
  } else {
    final lower = text.toLowerCase();
    if (lower == 'activo' || lower == 'culminó' || lower == 'culmino') {
      bg = Colors.green.shade100;
      fg = Colors.green.shade900;
    } else if (lower == 'inactivo' || lower.contains('retir')) {
      bg = Colors.orange.shade100;
      fg = Colors.orange.shade900;
    } else if (lower.contains('suspend')) {
      bg = Colors.red.shade100;
      fg = Colors.red.shade900;
    } else {
      bg = Colors.blue.shade50;
      fg = Colors.blue.shade900;
    }
  }

  return Align(
    alignment: Alignment.centerLeft,
    widthFactor: 1,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500),
      ),
    ),
  );
}

Widget tableActions({
  required VoidCallback onView,
  required List<PopupMenuEntry<String>> menuItems,
  required void Function(String) onMenuSelected,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        onPressed: onView,
        icon: const Icon(Icons.visibility_outlined, size: 18),
        tooltip: 'Ver',
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      ),
      PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        iconSize: 20,
        splashRadius: 18,
        onSelected: onMenuSelected,
        itemBuilder: (_) => menuItems,
      ),
    ],
  );
}

String dash(String? v) {
  if (v == null || v.trim().isEmpty || v == 'No registrado' || v == 'No registrada') {
    return '—';
  }
  return v.trim();
}
