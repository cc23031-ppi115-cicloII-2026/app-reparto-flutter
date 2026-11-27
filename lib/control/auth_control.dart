import 'dart:convert';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;
import '../entity/sesion_usuario.dart';
import 'db_local_control.dart';

class ResultadoLogin {
  final SesionUsuario? sesion;
  final String? error;
  final bool modoOffline;

  const ResultadoLogin({
    this.sesion,
    this.error,
    this.modoOffline = false,
  });

  bool get exitoso => sesion != null;
}

class AuthControl {
  final DbLocalControl _db = DbLocalControl();
  final String baseUrl;

  AuthControl({String? baseUrl}) : baseUrl = baseUrl ?? _resolverUrlPorDefecto();

  static String _resolverUrlPorDefecto() {
    const definida = String.fromEnvironment('API_URL', defaultValue: '');
    if (definida.isNotEmpty) return definida;
    if (kIsWeb) return 'http://localhost:8080';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  Future<SesionUsuario?> restaurarSesion() async {
    return await _db.obtenerSesionActiva();
  }

  Future<ResultadoLogin> iniciarSesion({
    required String usuario,
    required String password,
  }) async {
    final userTrim = usuario.trim();
    if (userTrim.isEmpty || password.isEmpty) {
      return const ResultadoLogin(error: 'Ingresa tu usuario y contraseña');
    }

    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/v1/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'usuario': userTrim,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final sesion = SesionUsuario.fromJson(data);
        await _db.guardarSesionActiva(sesion, password: password);
        return ResultadoLogin(sesion: sesion);
      }

      if (res.statusCode == 401 || res.statusCode == 400) {
        String mensaje = 'Usuario o contraseña incorrectos';
        try {
          final errData = jsonDecode(res.body);
          if (errData is Map && errData['error'] is Map) {
            mensaje = errData['error']['mensaje']?.toString() ?? mensaje;
          }
        } catch (_) {}
        return ResultadoLogin(error: mensaje);
      }
    } catch (_) {
      // Sin conexión al backend: intentar inicio de sesión con caché local
    }

    final sesionCache = await _db.autenticarOfflineCache(userTrim, password);
    if (sesionCache != null) {
      return ResultadoLogin(sesion: sesionCache, modoOffline: true);
    }

    return const ResultadoLogin(
      error:
          'No se pudo conectar con el servidor y no hay credenciales guardadas offline para este usuario.',
    );
  }

  Future<void> cerrarSesion() async {
    await _db.cerrarSesionLocal();
  }
}