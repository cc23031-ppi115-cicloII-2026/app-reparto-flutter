import 'package:flutter/material.dart';
import 'modules/shell/swoosh_shell_screen.dart';
import 'theme/swoosh_theme.dart';

void main() {
  runApp(const SwooshApp());
}

class SwooshApp extends StatelessWidget {
  const SwooshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swoosh - Gestión de Reparto',
      debugShowCheckedModeBanner: false,
      theme: SwooshTheme.lightTheme,
      home: const SwooshShellScreen(),
    );
  }
}