import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../entity/operacion_offline.dart';
import '../entity/pedido.dart';
import 'db_local_control.dart';
import 'sync_control.dart';

class PedidoControl {
  final DbLocalControl _db = DbLocalControl();
  final SyncControl _sync = SyncControl();
  final Uuid _uuid = const Uuid();

  Future<void> inicializar() async {
    _sync.iniciarMonitorRed();
    await _sync.sincronizarAhora();
    await cargarDatosDemoSiVacio();
  }

  Future<List<Pedido>> obtenerPedidos({String? repartidorId}) async {
    return await _db.obtenerPedidos(repartidorId: repartidorId);
  }

  Future<bool> actualizarEstadoPedido({
    required String pedidoId,
    required String nuevoEstado,
    String? repartidorId,
  }) async {
    final actual = await _db.obtenerPedidoPorId(pedidoId);
    if (actual == null) return false;

    final ahoraIso = DateTime.now().toUtc().toIso8601String();
    final entregadoEn = nuevoEstado == 'entregado' ? ahoraIso : actual.entregadoEn;

    final actualizado = actual.copyWith(
      estado: nuevoEstado,
      repartidorId: repartidorId ?? actual.repartidorId,
      entregadoEn: entregadoEn,
      sincronizado: false,
    );

    await _db.guardarPedido(actualizado);

    final payload = jsonEncode({
      'estado': nuevoEstado,
      'repartidor_id': ?actualizado.repartidorId,
      'entregado_en': ?entregadoEn,
    });

    final op = OperacionOffline(
      opId: _uuid.v4(),
      pedidoId: pedidoId,
      tipoOperacion: 'ACTUALIZAR_ESTADO',
      payloadJson: payload,
      creadoEnMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _db.encolarOperacion(op);

    _sync.sincronizarAhora();
    return true;
  }

  Future<List<Pedido>> obtenerRutaOptimizada({
    required String repartidorId,
    required Ubicacion origenActual,
  }) async {
    final pedidos = await _db.obtenerPedidos(repartidorId: repartidorId);
    final activos = pedidos
        .where((p) =>
            p.estado == 'pendiente' ||
            p.estado == 'asignado' ||
            p.estado == 'en_ruta')
        .toList();

    final ordenIds = await _sync.solicitarRutaOptimizada(
      repartidorId: repartidorId,
      origen: origenActual,
      paradas: activos,
    );

    if (ordenIds == null) return activos;

    final mapa = {for (final p in activos) p.id: p};
    final ordenados = <Pedido>[];
    for (final id in ordenIds) {
      if (mapa.containsKey(id)) {
        ordenados.add(mapa[id]!);
      }
    }
    return ordenados;
  }

  Future<int> obtenerCantidadPendientes() => _db.contarPendientes();
  Future<bool> hayConexion() => _sync.tieneConexion();
  int? obtenerUltimoTsyncMs() => _sync.ultimoTsyncMs;
  Future<void> forzarSincronizacion() => _sync.sincronizarAhora();

  Future<void> cargarDatosDemoSiVacio() async {
    final existentes = await _db.obtenerPedidos();
    if (existentes.isNotEmpty) return;

    final demo = [
      Pedido(
        id: _uuid.v4(),
        cliente: 'Comedor La Ceiba',
        direccion: 'Av. Independencia Sur, Santa Ana',
        ubicacion: Ubicacion(lat: 13.9942, lng: -89.5597),
        total: 14.50,
        estado: 'asignado',
        repartidorId: 'rep-1',
        creadoEn: DateTime.now().toUtc().toIso8601String(),
      ),
      Pedido(
        id: _uuid.v4(),
        cliente: 'Tienda El Progreso',
        direccion: 'Col. El Palmar, Santa Ana',
        ubicacion: Ubicacion(lat: 13.9875, lng: -89.5640),
        total: 22.00,
        estado: 'pendiente',
        repartidorId: 'rep-1',
        creadoEn: DateTime.now().toUtc().toIso8601String(),
      ),
      Pedido(
        id: _uuid.v4(),
        cliente: 'Pupusería Doña María',
        direccion: 'Barrio San Juan, Santa Ana',
        ubicacion: Ubicacion(lat: 13.9990, lng: -89.5521),
        total: 9.75,
        estado: 'pendiente',
        repartidorId: 'rep-1',
        creadoEn: DateTime.now().toUtc().toIso8601String(),
      ),
    ];

    await _db.guardarPedidos(demo);
  }
}