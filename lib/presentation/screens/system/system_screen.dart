/*import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:voluntariado_desktop_app/domain/volunteer/entities/volunteer.dart';
import 'package:voluntariado_desktop_app/infraestructure/datasources/api_volunteer_datasource_dart.dart';

class SystemScreen extends StatefulWidget {
  static const String name = 'system_screen';

  const SystemScreen({super.key});

  @override
  _SystemScreenState createState() => _SystemScreenState();
}

class _SystemScreenState extends State<SystemScreen> {
  late Future<List<Volunteer>> _volunteersFuture;
  List<Volunteer> _filteredVolunteers = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _volunteersFuture = ApiService.getVolunteers();
  }

  void _filterVolunteers(String query) {
    setState(() {
      if (query.isEmpty) {
        _volunteersFuture.then((volunteers) => _filteredVolunteers = volunteers);
      } else {
        _volunteersFuture.then((volunteers) {
          _filteredVolunteers = volunteers.where((volunteer) {
            final lowerQuery = query.toLowerCase();
            final matchesName = volunteer.name.toLowerCase().contains(lowerQuery);
            final matchesYear = volunteer.startDate != null && volunteer.startDate!.year.toString().contains(query);
            return matchesName || matchesYear;
          }).toList();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistema'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: Colors.white,
          onPressed: () {
            context.go('/');
          },
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o año de ingreso...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
              onChanged: _filterVolunteers,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Volunteer>>(
              future: _volunteersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator()); // 🔥 Loading mientras carga
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}')); // 🔥 Manejo de error
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No hay voluntarios disponibles.'));
                }

                if (_filteredVolunteers.isEmpty && _searchController.text.isNotEmpty) {
                  return const Center(child: Text('No se encontraron voluntarios con esos criterios.'));
                }

                final volunteers = _searchController.text.isEmpty ? snapshot.data! : _filteredVolunteers;

                return ListView.builder(
                  itemCount: volunteers.length,
                  itemBuilder: (context, index) {
                    final volunteer = volunteers[index];
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(volunteer.name),
                      subtitle: Text('CI: ${volunteer.ci} • Estado: ${volunteer.status}'),
                      trailing: Text(volunteer.formattedStartDate), // 🔥 Ahora muestra fecha de ingreso
                      onTap: () {
                        context.push('/volunteer/details/${volunteer.id}'); // 🔥 Navega a detalles del voluntario
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}*/

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:voluntariado_desktop_app/config/theme/app_theme.dart';

class SystemScreen extends StatelessWidget {
  static const String name = 'system_screen';

  const SystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary; // 🔥 Obtiene el color del tema

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistema'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, // 🔥 Centra los botones en la pantalla
          children: [
            _MenuButton(title: 'Voluntarios', icon: Icons.groups, color: themeColor, onTap: () => context.push('/volunteers')),
            const SizedBox(width: 16),
            _MenuButton(title: 'Estudiantes', icon: Icons.school, color: themeColor, onTap: () => context.push('/students')),
            const SizedBox(width: 16),
            _MenuButton(title: 'Otros', icon: Icons.category, color: themeColor, onTap: () => context.push('/others')),
          ],
        ),
      ),
    );
  }
}

// 🔥 Botón cuadrado con color del tema
class _MenuButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180, // 🔥 Botón más grande
        height: 180, // 🔥 Altura igual al ancho para forma cuadrada
        decoration: BoxDecoration(
          color: color, // 🔥 Usa el color del tema
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: const Offset(2, 2))], 
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.white), // 🔥 Ícono más grande
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}