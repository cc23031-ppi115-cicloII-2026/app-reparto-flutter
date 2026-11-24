import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../entity/pedido.dart';
import 'db_local_control.dart';

class SyncControl {
  final DbLocalControl _db = DbLocalControl();
  final String baseUrl;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _sincronizando = false;

  /// Último tiempo de sincronización medido en milisegundos (Tsync para metrología 10.2)
  int? ultimoTsyncMs;

  SyncControl({
    this.baseUrl = const String.fromEnvironment(
      'API_URL',
      defaultValue: 'http://10.0.2.2:3000',
    ),
  });

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
    final res = await Connectivity().checkConnectivity();
    return res.any((r) => r != ConnectivityResult.none);
  }

  Future<void> sincronizarAhora() async {
    if (_sincronizando) return;
    if (!await tieneConexion()) return;

    _sincronizando = true;
    final cronometro = Stopwatch()..start();

    try {
      final pendientes = await _db.obtenerOperacionesPendientes();

      for (final op in pendientes) {
        try {
          if (op.tipoOperacion == 'ACTUALIZAR_ESTADO') {
            final res = await http
                .patch(
                  Uri.parse('$baseUrl/api/v1/pedidos/${op.pedidoId}/estado'),
                  headers: {'Content-Type': 'application/json'},
                  body: op.payloadJson,
                )
                .timeout(const Duration(seconds: 5));

            if (res.statusCode == 200) {
              await _db.marcarOperacionEstado(op.opId, 'ENVIADA');
              final actualizado = Pedido.fromJson(jsonDecode(res.body));
              await _db.guardarPedido(actualizado);
            } else if (res.statusCode == 409) {
              await _db.marcarOperacionEstado(op.opId, 'CONFLICTO');
            } else {
              await _db.incrementarIntento(op.opId);
            }
          } else if (op.tipoOperacion == 'CREAR_PEDIDO') {
            final res = await http
                .post(
                  Uri.parse('$baseUrl/api/v1/pedidos'),
                  headers: {'Content-Type': 'application/json'},
                  body: op.payloadJson,
                )
                .timeout(const Duration(seconds: 5));

            if (res.statusCode == 201 || res.statusCode == 200) {
              await _db.marcarOperacionEstado(op.opId, 'ENVIADA');
              final creado = Pedido.fromJson(jsonDecode(res.body));
              await _db.guardarPedido(creado);
            } else {
              await _db.incrementarIntento(op.opId);
            }
          }
        } catch (_) {
          await _db.incrementarIntento(op.opId);
        }
      }

      await descargarPedidosRemotos();

      cronometro.stop();
      if (pendientes.isNotEmpty) {
        ultimoTsyncMs = cronometro.elapsedMilliseconds;
      }
    } finally {
      _sincronizando = false;
    }
  }

  Future<void> descargarPedidosRemotos() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/v1/pedidos'))
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final List<dynamic> lista = jsonDecode(res.body);
        final pedidos = lista.map((e) => Pedido.fromJson(e)).toList();
        await _db.guardarPedidos(pedidos);
      }
    } catch (_) {}
  }

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
        final data = jsonDecode(res.body);
        return List<String>.from(data['orden']);
      }
    } catch (_) {}
    return null;
  }
}