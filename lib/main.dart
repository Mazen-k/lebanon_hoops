import 'package:flutter/material.dart';
import 'auth/auth_gate.dart';
import 'theme/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LebanonHoopsApp());
}

class LebanonHoopsApp extends StatelessWidget {
  const LebanonHoopsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lebanon Hoops',
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}
