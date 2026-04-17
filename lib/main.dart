import 'package:flutter/material.dart';
import 'auth/auth_gate.dart';
import 'theme/theme.dart';

import 'theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = ThemeController();
  await themeController.init();
  runApp(const LebanonHoopsApp());
}

class LebanonHoopsApp extends StatelessWidget {
  const LebanonHoopsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController(),
      builder: (context, _) {
        return MaterialApp(
          title: 'Lebanon Hoops',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeController().themeMode,
          home: const AuthGate(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
