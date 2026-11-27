import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../entity/operacion_offline.dart';
import '../entity/pedido.dart';
import 'db_local_control.dart';
import 'sync_control.dart';

class PedidoControl {
  final DbLocalControl _db = DbLocalControl();
  final SyncControl _sync;
  final Uuid _uuid = const Uuid();

  PedidoControl({SyncControl? syncControl})
      : _sync = syncControl ?? SyncControl();

  /// 1. Inicializa DB local, monitor de red y sincronización.
  Stream<void> get cambiosSync => _sync.cambiosSync;

  Future<void> inicializar({String? repartidorId}) async {
    await _db.eliminarPedidosDePruebaConocidos();
    _sync.iniciarMonitorRed(repartidorId: repartidorId);
    await _sync.sincronizarAhora(repartidorId: repartidorId);
  }

  void dispose() => _sync.dispose();

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

    await _db.guardarPedidoYEncolarOperaciones(
      nuevo,
      _operacionesNuevoPedido(nuevo),
    );

    _sync.sincronizarAhora(repartidorId: nuevo.repartidorId);
    return nuevo;
  }

  Future<void> crearPedidoCompleto(Pedido pedido) async {
    final nuevo = pedido.copyWith(
      repartidorId: pedido.repartidorId ?? 'rep-1',
      estado: 'asignado',
      creadoEn: pedido.creadoEn ?? DateTime.now().toUtc().toIso8601String(),
      sincronizado: false,
    );

    await _db.guardarPedidoYEncolarOperaciones(
      nuevo,
      _operacionesNuevoPedido(nuevo),
    );
    unawaited(_sync.sincronizarAhora(repartidorId: nuevo.repartidorId));
  }

  List<OperacionOffline> _operacionesNuevoPedido(Pedido pedido) {
    final ahora = DateTime.now().millisecondsSinceEpoch;
    final operaciones = <OperacionOffline>[
      OperacionOffline(
        opId: _uuid.v4(),
        pedidoId: pedido.id,
        tipoOperacion: 'CREAR_PEDIDO',
        payloadJson: jsonEncode(pedido.toApiJson()),
        creadoEnMs: ahora,
      ),
    ];

    final repartidorId = pedido.repartidorId;
    if (repartidorId != null && repartidorId.isNotEmpty) {
      operaciones.add(OperacionOffline(
        opId: _uuid.v4(),
        pedidoId: pedido.id,
        tipoOperacion: 'ACTUALIZAR_ESTADO',
        payloadJson: jsonEncode({
          'estado': 'asignado',
          'repartidor_id': repartidorId,
        }),
        creadoEnMs: ahora + 1,
      ));
    }
    return operaciones;
  }

  /// 4. Actualiza el estado localmente (ej. 'entregado'), encola 'ACTUALIZAR_ESTADO' y sincroniza.
  Future<void> actualizarEstadoPedido({
    required String pedidoId,
    required String nuevoEstado,
    String? repartidorId,
  }) async {
    final actual = await _db.obtenerPedidoPorId(pedidoId);
    if (actual == null) return;
    if (actual.estado == nuevoEstado) return;

    final pendientesLocales = await _db.obtenerOperacionesPendientes();
    final creacionPendiente = pendientesLocales.any((operacion) =>
      operacion.pedidoId == pedidoId &&
      operacion.tipoOperacion == 'CREAR_PEDIDO');
    final asignacionPendiente = pendientesLocales.any((operacion) {
      if (operacion.pedidoId != pedidoId ||
          operacion.tipoOperacion != 'ACTUALIZAR_ESTADO') {
        return false;
      }
      final payload = jsonDecode(operacion.payloadJson) as Map<String, dynamic>;
      return payload['estado'] == 'asignado';
    });
    final estadoBase = creacionPendiente
        ? (asignacionPendiente ? 'asignado' : 'pendiente')
        : actual.estado;

    final estados = nuevoEstado == 'entregado'
      ? switch (estadoBase) {
            'pendiente' => ['asignado', 'en_ruta', 'entregado'],
            'asignado' => ['en_ruta', 'entregado'],
            'en_ruta' => ['entregado'],
            _ => <String>[],
          }
        : [nuevoEstado];
    if (estados.isEmpty) return;

    final ahoraIso = DateTime.now().toUtc().toIso8601String();
    final repId = repartidorId ?? actual.repartidorId;
    var actualizado = actual;
    final operaciones = <OperacionOffline>[];

    for (final estado in estados) {
      final entregadoEn = estado == 'entregado' ? ahoraIso : actualizado.entregadoEn;
      actualizado = actualizado.copyWith(
        estado: estado,
        repartidorId: repId,
        entregadoEn: entregadoEn,
        sincronizado: false,
      );

      final payloadMap = <String, dynamic>{'estado': estado};
      if (repId != null) payloadMap['repartidor_id'] = repId;
      if (entregadoEn != null) payloadMap['entregado_en'] = entregadoEn;
      operaciones.add(OperacionOffline(
        opId: _uuid.v4(),
        pedidoId: pedidoId,
        tipoOperacion: 'ACTUALIZAR_ESTADO',
        payloadJson: jsonEncode(payloadMap),
        creadoEnMs: DateTime.now().millisecondsSinceEpoch,
      ));
    }

    await _db.guardarPedidoYEncolarOperaciones(actualizado, operaciones);
    unawaited(_sync.sincronizarAhora(repartidorId: actualizado.repartidorId));
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

}