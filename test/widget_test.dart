import 'package:flutter_test/flutter_test.dart';
import 'package:app_reparto/main.dart';
import 'package:app_reparto/modules/shell/swoosh_shell_screen.dart';

void main() {
  testWidgets('Carga pantalla principal de Swoosh', (WidgetTester tester) async {
    await tester.pumpWidget(const SwooshApp());
    expect(find.byType(SwooshShellScreen), findsOneWidget);
  });
}