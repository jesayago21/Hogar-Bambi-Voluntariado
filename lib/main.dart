import 'package:voluntariado_desktop_app/config/theme/app_theme.dart';
import 'package:voluntariado_desktop_app/config/router/app_router.dart';
import 'dart:io';
import 'infraestructure/core/enviroments.dart';
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() async {
  await Environment.initEnvironment();

  /*  Process.run('cmd', [
        '/c',
        'start',
        '/B',
        'node',
        r'C:\Users\User\Documents\voluntariado_desktop_app\backendserver.js',
      ])
      .then((process) {
        print('✅ Server.js ha iniciado correctamente');
      })
      .catchError((error) {
        print('❌ Error al iniciar server.js: $error');
      });*/

  runApp(const MainApp());

  doWhenWindowReady(() {
    var initialState = const Size(1200, 700);
    appWindow.size = initialState;
    appWindow.minSize = initialState;
    appWindow.title = "Voluntariado Hogar Bambi";
  });
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Sistema Socio-legal Administrativo',
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      theme: AppTheme(selectedColor: 0).getTheme(),
    );
  }
}
