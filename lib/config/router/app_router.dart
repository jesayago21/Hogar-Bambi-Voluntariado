import 'package:go_router/go_router.dart';
import 'package:voluntariado_desktop_app/presentation/screens/home/home_screen.dart';
import 'package:voluntariado_desktop_app/presentation/screens/system/system_screen.dart';
import 'package:voluntariado_desktop_app/presentation/screens/info_volunteers/volunteers_screen.dart';
import 'package:voluntariado_desktop_app/presentation/screens/info_volunteers/volunteer_details_screen.dart';
import 'package:voluntariado_desktop_app/presentation/screens/system/students_screen.dart';
import 'package:voluntariado_desktop_app/presentation/screens/info_students/labor_social_screen.dart';
import 'package:voluntariado_desktop_app/presentation/screens/info_students/labor_social_details_screen.dart';
import 'package:voluntariado_desktop_app/presentation/screens/info_students/sevicio_comunitario_screen.dart';
import 'package:voluntariado_desktop_app/presentation/screens/info_students/servicio_comunitario_details_screen.dart';
import 'package:voluntariado_desktop_app/presentation/screens/info_students/pasantes_tesis_screen.dart';
import 'package:voluntariado_desktop_app/presentation/screens/info_students/pasantes_tesis_details_screen.dart';
import 'package:voluntariado_desktop_app/presentation/screens/info_students/otros_screen.dart';
import 'package:voluntariado_desktop_app/presentation/screens/info_students/otros_details_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [

    GoRoute(
      path: '/',
      name: HomeScreen.name,
      builder: (context, state) => const HomeScreen(),
    ),

    GoRoute(
      path: '/system',
      name: SystemScreen.name,
      builder: (context, state) => const SystemScreen(),
      ),
    
    GoRoute(
      path: '/volunteers',
      builder: (context, state) => VolunteersScreen(),
    ),
    GoRoute(
      path: '/volunteer/details/:id',
      builder: (context, state) {
        final int voluntarioId = int.parse(state.pathParameters['id']!); // 🔥 Convierte 'String' en 'int'
        return VoluntarioDetailsScreen(voluntarioId: voluntarioId);
      },
    ),
    GoRoute(
      path: '/students',
      builder: (context, state) => const StudentsScreen(),
    ),
    GoRoute(
    path: '/students/labor',
    builder: (context, state) => const LaborSocialScreen(),
    ),

    GoRoute(
    path: '/students/labor/:id',
    builder: (context, state) {
      final studentId = int.parse(state.pathParameters['id']!);
      return LaborSocialDetailsScreen(studentId: studentId);
    },
  ),

  GoRoute(
    path: '/students/community',
    builder: (context, state) => const CommunityServiceScreen(),
  ),

  GoRoute(
    path: '/students/community/:id',
    builder: (context, state) {
      final studentId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
      return CommunityServiceDetailsScreen(studentId: studentId);
    },
  ),
  GoRoute(
    path: '/students/internship',
    builder: (context, state) {
      return const InternshipThesisProjectScreen();
    },
  ),
  GoRoute(
    path: '/students/internship/:id',
    builder: (context, state) {
      final studentId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
      return InternshipThesisProjectDetailsScreen(studentId: studentId);
    },
  ),
  GoRoute(
    path: '/others',
    builder: (context, state) => const OtrosListScreen(),
  ),
  GoRoute(
    path: '/others/:id',
    builder: (context, state) {
      final studentId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
      return OtrosDetailsScreen(studentId: studentId);
    },
  ),
  ],

);