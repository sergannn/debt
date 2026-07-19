import 'package:debt_manager/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('opens the local loan list first', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const DebtManagerApp());
    await tester.pumpAndSettle();

    expect(find.text('АКТИВНЫЕ  3'), findsOneWidget);
    expect(find.text('Должники'), findsWidgets);
    expect(find.text('Заявки'), findsWidgets);
  });
}
