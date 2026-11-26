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

  /// 1. Inicializa DB local, monitor de red, sincronización y carga datos demo si está vacío.
  Future<void> inicializar() async {
    _sync.iniciarMonitorRed();
    await _sync.sincronizarAhora();
    await cargarDatosDemoSiVacio();
  }

  /// 2. Devuelve todos los pedidos locales (funciona offline).
  Future<List<Pedido>> obtenerPedidos({String? repartidorId}) async {
    return await _db.obtenerPedidos(repartidorId: repartidorId);
  }

  /// 3. Crea un pedido localmente con sincronizado: false, encola 'CREAR_PEDIDO' y sincroniza.
  Future<Pedido> crearPedido({
    required String cliente,
    required String direccion,
    required Ubicacion ubicacion,
    required double total,
    String? repartidorId,
  }) async {
    final nuevo = Pedido(
      id: _uuid.v4(),
      cliente: cliente,
      direccion: direccion,
      ubicacion: ubicacion,
      total: total,
      estado: 'asignado',
      repartidorId: repartidorId ?? 'rep-1',
      creadoEn: DateTime.now().toUtc().toIso8601String(),
      sincronizado: false,
    );

    await _db.guardarPedido(nuevo);
    await _db.encolarOperacion(OperacionOffline(
      opId: _uuid.v4(),
      pedidoId: nuevo.id,
      tipoOperacion: 'CREAR_PEDIDO',
      payloadJson: jsonEncode(nuevo.toApiJson()),
      creadoEnMs: DateTime.now().millisecondsSinceEpoch,
    ));

    _sync.sincronizarAhora(repartidorId: nuevo.repartidorId);
    return nuevo;
  }

  /// 4. Actualiza el estado localmente (ej. 'entregado'), encola 'ACTUALIZAR_ESTADO' y sincroniza.
  Future<void> actualizarEstadoPedido({
    required String pedidoId,
    required String nuevoEstado,
    String? repartidorId,
  }) async {
    final actual = await _db.obtenerPedidoPorId(pedidoId);
    if (actual == null) return;

    final ahoraIso = DateTime.now().toUtc().toIso8601String();
    final entregadoEn = nuevoEstado == 'entregado' ? ahoraIso : actual.entregadoEn;

    final actualizado = actual.copyWith(
      estado: nuevoEstado,
      repartidorId: repartidorId ?? actual.repartidorId,
      entregadoEn: entregadoEn,
      sincronizado: false,
    );

    await _db.guardarPedido(actualizado);

    final Map<String, dynamic> payloadMap = {'estado': nuevoEstado};
    if (actualizado.repartidorId != null) {
      payloadMap['repartidor_id'] = actualizado.repartidorId;
    }
    if (entregadoEn != null) {
      payloadMap['entregado_en'] = entregadoEn;
    }
    final payload = jsonEncode(payloadMap);

    final op = OperacionOffline(
      opId: _uuid.v4(),
      pedidoId: pedidoId,
      tipoOperacion: 'ACTUALIZAR_ESTADO',
      payloadJson: payload,
      creadoEnMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _db.encolarOperacion(op);

    _sync.sincronizarAhora(repartidorId: actualizado.repartidorId);
  }

  /// 5. Llama a POST /api/v1/rutas/optimizar si hay red, o usa fallback local si está offline.
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
      final pedido = mapa.remove(id);
      if (pedido != null) {
        ordenados.add(pedido);
      }
    }
    ordenados.addAll(mapa.values);
    return ordenados;
  }

  /// 6. Métodos de telemetría y control manual de sincronización para la UI
  Future<bool> hayConexion() => _sync.tieneConexion();
  Future<int> obtenerCantidadPendientes() => _db.contarPendientes();
  int? obtenerUltimoTsyncMs() => _sync.ultimoTsyncMs;
  Future<void> forzarSincronizacion() => _sync.sincronizarAhora();

  Future<void> cargarDatosDemoSiVacio() async {
    final existentes = await _db.obtenerPedidos();
    if (existentes.isNotEmpty) return;

    final ahora = DateTime.now().toUtc().toIso8601String();
    final demo = [
      Pedido(
        id: _uuid.v4(),
        cliente: 'Comedor La Ceiba',
        direccion: 'Av. Independencia Sur, Santa Ana',
        ubicacion: const Ubicacion(lat: 13.9942, lng: -89.5597),
        total: 14.50,
        estado: 'asignado',
        repartidorId: 'rep-1',
        creadoEn: ahora,
      ),
      Pedido(
        id: _uuid.v4(),
        cliente: 'Tienda El Progreso',
        direccion: 'Col. El Palmar, Santa Ana',
        ubicacion: const Ubicacion(lat: 13.9875, lng: -89.5640),
        total: 22.00,
        estado: 'pendiente',
        repartidorId: 'rep-1',
        creadoEn: ahora,
      ),
      Pedido(
        id: _uuid.v4(),
        cliente: 'Pupusería Doña María',
        direccion: 'Barrio San Juan, Santa Ana',
        ubicacion: const Ubicacion(lat: 13.9990, lng: -89.5521),
        total: 9.75,
        estado: 'pendiente',
        repartidorId: 'rep-1',
        creadoEn: ahora,
      ),
    ];

    await _db.guardarPedidos(demo);
  }
}