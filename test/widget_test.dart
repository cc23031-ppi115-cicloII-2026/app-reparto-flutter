import 'package:flutter_test/flutter_test.dart';

import 'package:app_reparto/main.dart';
import 'package:app_reparto/screens/reparto_home_screen.dart';

void main() {
  testWidgets('the app opens the delivery control screen', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(RepartoHomeScreen), findsOneWidget);
  });
}
