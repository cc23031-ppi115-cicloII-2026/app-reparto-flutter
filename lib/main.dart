import 'package:flutter/material.dart';
import 'control/auth_control.dart';
import 'entity/sesion_usuario.dart';
import 'modules/auth/login_screen.dart';
import 'modules/shell/swoosh_shell_screen.dart';
import 'theme/swoosh_theme.dart';

void main() {
  runApp(const SwooshApp());
}

class SwooshApp extends StatefulWidget {
  const SwooshApp({super.key});

  @override
  State<SwooshApp> createState() => _SwooshAppState();
}

class _SwooshAppState extends State<SwooshApp> {
  final AuthControl _authControl = AuthControl();
  SesionUsuario? _sesion;
  bool _cargandoSesion = true;

  @override
  void initState() {
    super.initState();
    _verificarSesion();
  }

  Future<void> _verificarSesion() async {
    final sesionGuardada = await _authControl.restaurarSesion();
    if (!mounted) return;
    setState(() {
      _sesion = sesionGuardada;
      _cargandoSesion = false;
    });
  }

  Future<void> _cerrarSesion() async {
    await _authControl.cerrarSesion();
    if (!mounted) return;
    setState(() => _sesion = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swoosh - Gestión de Reparto',
      debugShowCheckedModeBanner: false,
      theme: SwooshTheme.lightTheme,
      home: _cargandoSesion
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : _sesion == null
              ? LoginScreen(
                  onLoginExitoso: (nuevaSesion) =>
                      setState(() => _sesion = nuevaSesion),
                )
              : SwooshShellScreen(
                  sesion: _sesion!,
                  onCerrarSesion: _cerrarSesion,
                ),
    );
  }
}