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
  Timer? _reintentoTimer;
  final StreamController<void> _cambiosSync = StreamController<void>.broadcast();
  bool _sincronizando = false;
  bool _apiDisponible = false;

  /// Último tiempo de sincronización medido en milisegundos (Tsync para metrología)
  int? ultimoTsyncMs;

  SyncControl({String? baseUrl}) : baseUrl = baseUrl ?? _resolverUrlPorDefecto();

  Stream<void> get cambiosSync => _cambiosSync.stream;

  static String _resolverUrlPorDefecto() {
    const definida = String.fromEnvironment('API_URL', defaultValue: '');
    if (definida.isNotEmpty) return definida;
    if (kIsWeb) return 'http://localhost:8080';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  void iniciarMonitorRed({String? repartidorId}) {
    _sub?.cancel();
    _sub = Connectivity().onConnectivityChanged.listen((resultados) {
      final hayRed = resultados.any((r) => r != ConnectivityResult.none);
      if (hayRed) {
        unawaited(sincronizarAhora(repartidorId: repartidorId));
      }
    });
    _reintentoTimer?.cancel();
    _reintentoTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(sincronizarAhora(repartidorId: repartidorId));
    });
  }

  void detenerMonitorRed() {
    _sub?.cancel();
    _reintentoTimer?.cancel();
  }

  void dispose() {
    detenerMonitorRed();
    unawaited(_cambiosSync.close());
  }

  Future<bool> tieneConexion() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      _apiDisponible = res.statusCode == 200;
    } catch (_) {
      _apiDisponible = false;
    }
    return _apiDisponible;
  }

  /// Envía todas las operaciones pendientes de la cola offline y descarga datos remotos.
  Future<void> sincronizarAhora({String? repartidorId}) async {
    if (_sincronizando) return;
    _sincronizando = true;
    final cronometro = Stopwatch()..start();

    try {
      if (!await tieneConexion()) return;

      final pendientes = await _db.obtenerOperacionesPendientes();
      final pedidosEnConflicto = <String>{};

      for (final op in pendientes) {
        if (pedidosEnConflicto.contains(op.pedidoId)) continue;
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
              await _guardarPedidoSinPisarPendientes(creado, op.pedidoId);
            } else if (res.statusCode == 409) {
              await _db.marcarOperacionEstado(op.opId, 'CONFLICTO');
              await _db.marcarOperacionesPendientesDelPedidoComoConflicto(
                op.pedidoId,
              );
              pedidosEnConflicto.add(op.pedidoId);
            } else {
              await _db.incrementarIntento(op.opId);
              break;
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
              await _guardarPedidoSinPisarPendientes(actualizado, op.pedidoId);
            } else if (res.statusCode == 409) {
              await _db.marcarOperacionEstado(op.opId, 'CONFLICTO');
              await _db.marcarOperacionesPendientesDelPedidoComoConflicto(
                op.pedidoId,
              );
              pedidosEnConflicto.add(op.pedidoId);
            } else {
              await _db.incrementarIntento(op.opId);
              break;
            }
          }
        } catch (_) {
          await _db.incrementarIntento(op.opId);
          break;
        }
      }

      if (!await descargarPedidosRemotos(repartidorId: repartidorId)) {
        _apiDisponible = false;
      }

      cronometro.stop();
      if (pendientes.isNotEmpty) {
        ultimoTsyncMs = cronometro.elapsedMilliseconds;
      }
    } finally {
      _sincronizando = false;
      if (!_cambiosSync.isClosed) _cambiosSync.add(null);
    }
  }

  Future<bool> descargarPedidosRemotos({String? repartidorId}) async {
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

        final idsConPendientes = await _db.obtenerPedidoIdsConPendientes();
        final paraGuardar = remotos
            .where((p) => !idsConPendientes.contains(p.id))
            .toList();

        await _db.guardarPedidos(paraGuardar);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _guardarPedidoSinPisarPendientes(
    Pedido respuestaRemota,
    String pedidoId,
  ) async {
    final quedanPendientes = (await _db.obtenerOperacionesPendientes())
        .any((operacion) => operacion.pedidoId == pedidoId);
    if (!quedanPendientes) {
      await _db.guardarPedido(respuestaRemota);
      return;
    }

    final local = await _db.obtenerPedidoPorId(pedidoId);
    if (local == null) {
      await _db.guardarPedido(respuestaRemota);
      return;
    }
    await _db.guardarPedido(local.copyWith(
      rev: respuestaRemota.rev,
      sincronizado: false,
    ));
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