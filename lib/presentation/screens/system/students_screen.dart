import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:voluntariado_desktop_app/config/theme/app_theme.dart';

class StudentsScreen extends StatelessWidget {
  static const String name = 'students_screen';

  const StudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estudiantes'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/system'),
        ),
      ),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MenuButton(title: 'Labor Social', icon: Icons.handshake, color: themeColor, onTap: () => context.push('/students/labor')),
            const SizedBox(width: 16),
            _MenuButton(title: 'Serv. Comunitario', icon: Icons.volunteer_activism, color: themeColor, onTap: () => context.push('/students/community')),
            const SizedBox(width: 16),
            _MenuButton(title: 'Pasantías, Tesis y Proy.', icon: Icons.work, color: themeColor, onTap: () => context.push('/students/internship')),
          ],
        ),
      ),
    );
  }
}

// 🔥 Botón cuadrado reutilizable
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
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: const Offset(2, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.white),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}