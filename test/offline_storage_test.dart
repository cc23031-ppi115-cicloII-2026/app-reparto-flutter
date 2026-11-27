import 'dart:convert';

import 'package:app_reparto/control/db_local_control.dart';
import 'package:app_reparto/control/pedido_control.dart';
import 'package:app_reparto/control/sync_control.dart';
import 'package:app_reparto/entity/operacion_offline.dart';
import 'package:app_reparto/entity/pedido.dart';
import 'package:app_reparto/entity/sesion_usuario.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DbLocalControl().eliminarPedidosDePruebaConocidos();
  });

  tearDownAll(() async {
    await DbLocalControl().eliminarPedidosDePruebaConocidos();
  });

  test('devuelve los pedidos más recientes primero', () async {
    final db = DbLocalControl();
    await db.guardarPedidos([
      Pedido(
        id: 'orden-antiguo',
        cliente: 'Pedido antiguo',
        direccion: 'Calle 1',
        ubicacion: const Ubicacion(lat: 13.99, lng: -89.55),
        total: 5,
        estado: 'pendiente',
        repartidorId: 'rep-orden-test',
        creadoEn: '2026-01-01T10:00:00Z',
      ),
      Pedido(
        id: 'orden-reciente',
        cliente: 'Pedido reciente',
        direccion: 'Calle 2',
        ubicacion: const Ubicacion(lat: 13.98, lng: -89.56),
        total: 8,
        estado: 'pendiente',
        repartidorId: 'rep-orden-test',
        creadoEn: '2026-01-02T10:00:00Z',
      ),
    ]);

    final pedidos = await db.obtenerPedidos(repartidorId: 'rep-orden-test');
    expect(pedidos.map((pedido) => pedido.id), [
      'orden-reciente',
      'orden-antiguo',
    ]);
    await db.eliminarPedidoLocal('orden-reciente');
    await db.eliminarPedidoLocal('orden-antiguo');
  });

  test('conserva sesión, entrega local y cola pendiente en SQLite', () async {
    final db = DbLocalControl();
    final pendientesAntes = await db.contarPendientes();
    final id = 'offline-${DateTime.now().microsecondsSinceEpoch}';
    final sesion = SesionUsuario(
      usuario: id,
      rol: 'repartidor',
      nombre: 'Repartidor de prueba',
      repartidorId: 'rep-offline',
    );

    await db.guardarSesionActiva(sesion, password: 'clave-prueba');
    final sesionOffline = await db.autenticarOfflineCache(id, 'clave-prueba');
    expect(sesionOffline?.repartidorId, 'rep-offline');

    final pedido = Pedido(
      id: id,
      cliente: 'Cliente sin conexión',
      direccion: 'Calle de prueba',
      ubicacion: const Ubicacion(lat: 13.99, lng: -89.55),
      total: 12.5,
      estado: 'entregado',
      repartidorId: 'rep-offline',
      entregadoEn: DateTime.now().toUtc().toIso8601String(),
      sincronizado: false,
    );
    await db.guardarPedido(pedido);
    await db.encolarOperacion(OperacionOffline(
      opId: '$id-op',
      pedidoId: id,
      tipoOperacion: 'ACTUALIZAR_ESTADO',
      payloadJson: '{"estado":"entregado"}',
      creadoEnMs: DateTime.now().millisecondsSinceEpoch,
    ));

    expect((await db.obtenerPedidoPorId(id))?.estado, 'entregado');
    expect((await db.obtenerPedidoPorId(id))?.sincronizado, isFalse);
    expect(await db.contarPendientes(), pendientesAntes + 1);
    expect(
      (await db.obtenerOperacionesPendientes())
          .singleWhere((operacion) => operacion.opId == '$id-op')
          .pedidoId,
      id,
    );
    await db.cerrarSesionLocal();
  });

  test('encola estados aceptados por la API al entregar desde pendiente', () async {
    final db = DbLocalControl();
    final control = PedidoControl(
      syncControl: SyncControl(baseUrl: 'http://127.0.0.1:1'),
    );
    final id = 'transicion-${DateTime.now().microsecondsSinceEpoch}';
    await db.guardarPedido(Pedido(
      id: id,
      cliente: 'Entrega de prueba',
      direccion: 'Calle de prueba',
      ubicacion: const Ubicacion(lat: 13.99, lng: -89.55),
      total: 8,
      estado: 'pendiente',
      repartidorId: 'rep-prueba',
    ));

    await control.actualizarEstadoPedido(
      pedidoId: id,
      nuevoEstado: 'entregado',
      repartidorId: 'rep-prueba',
    );

    final local = await db.obtenerPedidoPorId(id);
    final operaciones = (await db.obtenerOperacionesPendientes())
        .where((operacion) => operacion.pedidoId == id)
        .toList();
    expect(local?.estado, 'entregado');
    expect(local?.sincronizado, isFalse);
    expect(
      operaciones
          .map((operacion) =>
              (jsonDecode(operacion.payloadJson) as Map<String, dynamic>)['estado'])
          .toList(),
      ['asignado', 'en_ruta', 'entregado'],
    );
    expect(
      operaciones[1].creadoEnMs,
      greaterThan(operaciones[0].creadoEnMs),
    );
    expect(
      operaciones[2].creadoEnMs,
      greaterThan(operaciones[1].creadoEnMs),
    );
    control.dispose();
  });

  test('incluye la asignación al entregar un pedido creado offline', () async {
    final db = DbLocalControl();
    final control = PedidoControl(
      syncControl: SyncControl(baseUrl: 'http://127.0.0.1:1'),
    );
    final nuevo = await control.crearPedido(
      cliente: 'Pedido creado offline',
      direccion: 'Calle de prueba',
      ubicacion: const Ubicacion(lat: 13.99, lng: -89.55),
      total: 9,
      repartidorId: 'rep-prueba',
    );
    await control.actualizarEstadoPedido(
      pedidoId: nuevo.id,
      nuevoEstado: 'entregado',
      repartidorId: 'rep-prueba',
    );

    final operaciones = (await db.obtenerOperacionesPendientes())
        .where((operacion) => operacion.pedidoId == nuevo.id)
        .toList();
    expect(operaciones.first.tipoOperacion, 'CREAR_PEDIDO');
    expect(
      operaciones
          .skip(1)
          .map((operacion) =>
              (jsonDecode(operacion.payloadJson) as Map<String, dynamic>)['estado'])
          .toList(),
      ['asignado', 'en_ruta', 'entregado'],
    );
    expect((await db.obtenerPedidoPorId(nuevo.id))?.estado, 'entregado');
    control.dispose();
  });
}