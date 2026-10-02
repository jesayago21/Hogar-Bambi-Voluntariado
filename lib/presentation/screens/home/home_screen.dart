import 'package:flutter/material.dart';
import 'package:voluntariado_desktop_app/presentation/screens/home/widgets/main_drawer_widget.dart';

class HomeScreen extends StatelessWidget {
  static const String name = 'home_screen';

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hogar Bambi Venezuela'),
        iconTheme: const IconThemeData(
          color: Colors.white, // Cambia este color al que desees
        ),
        /*leading: Builder( // Envuelve el botón en Builder para un contexto válido
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu), // Botón de menú
              onPressed: () {
                Scaffold.of(context).openDrawer(); // Abre el menú lateral
              },
            );
          },
        ),*/
      ),
      drawer: const MainDrawer(), // Menú lateral
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Sistema de Gestion:\n Direccion Administrativa de Voluntariado',
              style: TextStyle(
                fontSize: 36,
                color: colors.primary,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20, width: 20),
            Image.asset('assets/images/HBV_logo.png', width: 200, height: 200),
          ],
        ),
      ),
    );
  }
}