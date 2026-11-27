import 'package:app_reparto/entity/pedido.dart';
import 'package:app_reparto/modules/entregas/entregas_module_screen.dart';
import 'package:app_reparto/modules/mapa_ruta/mapa_ruta_module_screen.dart';
import 'package:app_reparto/modules/metricas/metricas_module_screen.dart';
import 'package:app_reparto/theme/swoosh_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final pedidos = [
    Pedido(
      id: 'pedido-efectivo',
      cliente: 'Cliente Efectivo',
      direccion: 'Calle 1',
      ubicacion: const Ubicacion(lat: 13.99, lng: -89.55),
      total: 10,
      metodoPago: 'efectivo',
      estado: 'asignado',
    ),
    Pedido(
      id: 'pedido-transferencia',
      cliente: 'Cliente Transferencia',
      direccion: 'Calle 2',
      ubicacion: const Ubicacion(lat: 13.98, lng: -89.56),
      total: 20,
      metodoPago: 'transferencia',
      estado: 'entregado',
    ),
    Pedido(
      id: 'pedido-cancelado',
      cliente: 'Cliente Cancelado',
      direccion: 'Calle 3',
      ubicacion: const Ubicacion(lat: 13.97, lng: -89.57),
      total: 30,
      estado: 'cancelado',
    ),
  ];

  testWidgets('los filtros del resumen se pueden seleccionar y deseleccionar',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MetricasModuleScreen(
            pedidos: pedidos,
            ultimoTsyncMs: null,
            pendientesSync: 0,
          ),
        ),
      ),
    );

    expect(_chip(tester, 'Todos (2)').selected, isTrue);
    await tester.tap(find.text('Entregados (1)'));
    await tester.pumpAndSettle();
    expect(_chip(tester, 'Entregados (1)').selected, isTrue);
    expect(find.text('Detalle de Movimientos (1)'), findsOneWidget);

    await tester.tap(find.text('Entregados (1)'));
    await tester.pumpAndSettle();
    expect(_chip(tester, 'Entregados (1)').selected, isFalse);
    expect(find.text('Detalle de Movimientos (2)'), findsOneWidget);

    await tester.tap(find.text('Solo Efectivo'));
    await tester.pumpAndSettle();
    expect(_chip(tester, 'Solo Efectivo').selected, isTrue);
    expect(find.text('Detalle de Movimientos (1)'), findsOneWidget);

    await tester.tap(find.text('Solo Efectivo'));
    await tester.pumpAndSettle();
    expect(_chip(tester, 'Solo Efectivo').selected, isFalse);
    expect(find.text('Detalle de Movimientos (2)'), findsOneWidget);
  });

  testWidgets('el botón Entregar de pedidos es azul', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EntregasModuleScreen(
          pedidos: [pedidos.first],
          isOnline: false,
          ubicacionActual: const Ubicacion(lat: 13.99, lng: -89.55),
          onCambiarEstado: (_, _) async {},
          onCrearPedido: (_, _, _, _) async {},
        ),
      ),
    );

    final boton = tester.widget<ElevatedButton>(find.ancestor(
      of: find.text('Entregar'),
      matching: find.byType(ElevatedButton),
    ));
    expect(boton.style?.backgroundColor?.resolve({}), SwooshColors.azulPrimario);
  });

  testWidgets('el botón del repartidor solo muestra Marcar como entregado',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BotonMarcarComoEntregado(onPressed: () {}),
        ),
      ),
    );

    final botonFinder = find.byType(BotonMarcarComoEntregado);
    expect(botonFinder, findsOneWidget);
    expect(find.text('Marcar como entregado'), findsOneWidget);
    expect(
      find.descendant(of: botonFinder, matching: find.byType(Icon)),
      findsNothing,
    );
    expect(find.text('Entregado'), findsNothing);
  });
}

ChoiceChip _chip(WidgetTester tester, String label) {
  return tester.widget<ChoiceChip>(find.ancestor(
    of: find.text(label),
    matching: find.byType(ChoiceChip),
  ));
}