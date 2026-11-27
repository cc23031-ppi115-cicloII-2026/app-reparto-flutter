import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_reparto/control/pedido_control.dart';
import 'package:app_reparto/entity/pedido.dart';
import 'package:app_reparto/entity/sesion_usuario.dart';
import 'package:app_reparto/modules/shell/swoosh_shell_screen.dart';

void main() {
  testWidgets('negocio1 muestra Pedidos y Resumen sin Online ni Replicación', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_shellForRole('negocio1'));

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(
      navigationBar.destinations.map(
        (destination) => (destination as NavigationDestination).label,
      ),
      ['Pedidos', 'Resumen'],
    );
    expect(navigationBar.selectedIndex, 0);
    expect(find.byType(ActionChip), findsNothing);
    expect(find.text('Online'), findsNothing);
    expect(find.text('Replicación'), findsNothing);
  });

  testWidgets('rep1 muestra solo Mapa Ruta y conserva un índice válido', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_shellForRole('negocio1'));
    tester
        .widget<NavigationBar>(find.byType(NavigationBar))
        .onDestinationSelected!(1);
    await tester.pump();

    await tester.pumpWidget(_shellForRole('rep1'));
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Mapa Ruta'), findsOneWidget);
    expect(find.text('Pedidos'), findsNothing);
    expect(find.text('Resumen'), findsNothing);
  });
}

Widget _shellForRole(String role) {
  return MaterialApp(
    home: SwooshShellScreen(
      sesion: SesionUsuario(
        usuario: 'usuario',
        rol: role,
        nombre: 'Usuario de prueba',
      ),
      onCerrarSesion: () async {},
      pedidoControl: _PedidoControlFake(),
    ),
  );
}

class _PedidoControlFake extends PedidoControl {
  @override
  Stream<void> get cambiosSync => const Stream<void>.empty();

  @override
  Future<void> inicializar({String? repartidorId}) async {}

  @override
  Future<List<Pedido>> obtenerPedidos({String? repartidorId}) async => [];

  @override
  Future<bool> hayConexion() async => false;

  @override
  Future<int> obtenerCantidadPendientes() async => 0;

  @override
  int? obtenerUltimoTsyncMs() => null;

  @override
  void dispose() {}
}
