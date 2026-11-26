import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;
import '../entity/pedido.dart';
import 'db_local_control.dart';

class SyncControl {
  final DbLocalControl _db = DbLocalControl();
  final String baseUrl;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _sincronizando = false;

  /// Último tiempo de sincronización medido en milisegundos (Tsync para metrología)
  int? ultimoTsyncMs;

  SyncControl({String? baseUrl}) : baseUrl = baseUrl ?? _resolverUrlPorDefecto();

  static String _resolverUrlPorDefecto() {
    const definida = String.fromEnvironment('API_URL', defaultValue: '');
    if (definida.isNotEmpty) return definida;
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  void iniciarMonitorRed() {
    _sub?.cancel();
    _sub = Connectivity().onConnectivityChanged.listen((resultados) async {
      final hayRed = resultados.any((r) => r != ConnectivityResult.none);
      if (hayRed) {
        await sincronizarAhora();
      }
    });
  }

  void detenerMonitorRed() {
    _sub?.cancel();
  }

  Future<bool> tieneConexion() async {
    try {
      final res = await Connectivity().checkConnectivity();
      return res.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  /// Envía todas las operaciones pendientes de la cola offline y descarga datos remotos.
  Future<void> sincronizarAhora({String? repartidorId}) async {
    if (_sincronizando) return;
    if (!await tieneConexion()) return;

    _sincronizando = true;
    final cronometro = Stopwatch()..start();

    try {
      final pendientes = await _db.obtenerOperacionesPendientes();

      for (final op in pendientes) {
        try {
          if (op.tipoOperacion == 'CREAR_PEDIDO') {
            final res = await http
                .post(
                  Uri.parse('$baseUrl/api/v1/pedidos'),
                  headers: {'Content-Type': 'application/json'},
                  body: op.payloadJson,
                )
                .timeout(const Duration(seconds: 5));

            if (res.statusCode == 201 || res.statusCode == 200) {
              await _db.marcarOperacionEstado(op.opId, 'ENVIADA');
              final creado = Pedido.fromJson(
                jsonDecode(res.body) as Map<String, dynamic>,
              );
              if (creado.id != op.pedidoId) {
                await _db.eliminarPedidoLocal(op.pedidoId);
              }
              await _db.guardarPedido(creado);
            } else if (res.statusCode == 409) {
              await _db.marcarOperacionEstado(op.opId, 'CONFLICTO');
            } else {
              await _db.incrementarIntento(op.opId);
            }
          } else if (op.tipoOperacion == 'ACTUALIZAR_ESTADO') {
            final res = await http
                .patch(
                  Uri.parse('$baseUrl/api/v1/pedidos/${op.pedidoId}/estado'),
                  headers: {'Content-Type': 'application/json'},
                  body: op.payloadJson,
                )
                .timeout(const Duration(seconds: 5));

            if (res.statusCode == 200) {
              await _db.marcarOperacionEstado(op.opId, 'ENVIADA');
              final actualizado = Pedido.fromJson(
                jsonDecode(res.body) as Map<String, dynamic>,
              );
              await _db.guardarPedido(actualizado);
            } else if (res.statusCode == 409) {
              await _db.marcarOperacionEstado(op.opId, 'CONFLICTO');
            } else {
              await _db.incrementarIntento(op.opId);
            }
          }
        } catch (_) {
          await _db.incrementarIntento(op.opId);
        }
      }

      await descargarPedidosRemotos(repartidorId: repartidorId);

      cronometro.stop();
      if (pendientes.isNotEmpty) {
        ultimoTsyncMs = cronometro.elapsedMilliseconds;
      }
    } finally {
      _sincronizando = false;
    }
  }

  Future<void> descargarPedidosRemotos({String? repartidorId}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/pedidos').replace(
        queryParameters: (repartidorId != null && repartidorId.isNotEmpty)
            ? {'repartidor_id': repartidorId}
            : null,
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final List<dynamic> lista = jsonDecode(res.body) as List<dynamic>;
        final remotos = lista
            .map((e) => Pedido.fromJson(e as Map<String, dynamic>))
            .toList();

        // No sobrescribir pedidos locales que aún tienen operaciones pendientes en cola
        final idsConPendientes = await _db.obtenerPedidoIdsConPendientes();
        final paraGuardar = remotos
            .where((p) => !idsConPendientes.contains(p.id))
            .toList();

        await _db.guardarPedidos(paraGuardar);
      }
    } catch (_) {}
  }

  /// Solicita el orden óptimo de paradas al endpoint POST /api/v1/rutas/optimizar
  Future<List<String>?> solicitarRutaOptimizada({
    required String repartidorId,
    required Ubicacion origen,
    required List<Pedido> paradas,
  }) async {
    if (!await tieneConexion() || paradas.isEmpty) return null;

    try {
      final body = jsonEncode({
        'repartidor_id': repartidorId,
        'origen': origen.toJson(),
        'paradas': paradas
            .map((p) => {
                  'pedido_id': p.id,
                  'ubicacion': p.ubicacion.toJson(),
                })
            .toList(),
      });

      final res = await http
          .post(
            Uri.parse('$baseUrl/api/v1/rutas/optimizar'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final orden = data['orden'];
        if (orden is List) {
          return orden.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {}
    return null;
  }
}