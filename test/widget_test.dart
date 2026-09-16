import 'package:debt_manager/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('loan balance supports manual dates, payments, and archive flag', () {
    final issued = DateTime(2026, 8, 10);
    final due = DateTime(2026, 9, 10);
    final loan = Loan(
      id: 'loan-test',
      debtorName: 'Стручок',
      phone: '',
      principal: 300000,
      repaymentAmount: 330000,
      issuedAt: issued,
      dueAt: due,
      dailyPercent: 0,
      note: '',
    );

    expect(loan.expectedDue, 330000);
    expect(loan.remainingDue, 330000);
    expect(daysBetweenInclusive(issued, due), 32);

    final moved = loan.copyWith(
      dueAt: DateTime(2026, 9, 12),
      paidAmount: 50000,
      archivedAt: DateTime(2026, 9, 13),
    );

    expect(moved.dueAt, DateTime(2026, 9, 12));
    expect(moved.paidAmount, 50000);
    expect(moved.remainingDue, 280000);
    expect(moved.archivedAt, isNotNull);
  });

  test('calendar month helper keeps same day when possible', () {
    expect(addMonths(DateTime(2026, 8, 10), 1), DateTime(2026, 9, 10));
    expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
  });

  testWidgets('opens the local loan list first', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const DebtManagerApp());
    await tester.pumpAndSettle();

    expect(find.text('АКТИВНЫЕ  3'), findsOneWidget);
    expect(find.text('Должники'), findsWidgets);
    expect(find.text('Заявки'), findsWidgets);
  });

  testWidgets(
    'loan details exposes edit, payment, extra loan, archive and delete actions',
    (tester) async {
      final loan = Loan(
        id: 'loan-test',
        debtorName: 'Стручок',
        phone: '',
        principal: 300000,
        repaymentAmount: 330000,
        issuedAt: DateTime(2026, 8, 10),
        dueAt: DateTime(2026, 9, 10),
        dailyPercent: 0,
        note: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LoanDetailsPage(
            loan: loan,
            onEditLoan: (loan) async => loan.copyWith(
              dueAt: DateTime(2026, 9, 12),
              expectedReturnAmount: 335000,
            ),
            onAddPayment: (loan) async => loan.copyWith(paidAmount: 50000),
            onAddLoanForDebtor: (_) async {},
            onArchiveLoan: (loan) async =>
                loan.copyWith(archivedAt: DateTime(2026, 9, 13)),
            onDeleteLoan: (_) async => true,
            onCloseEarly: (loan) async =>
                loan..closedAt = DateTime(2026, 9, 10),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Редактировать'), findsOneWidget);
      expect(find.text('Еще займ'), findsOneWidget);
      expect(find.text('Частичная оплата'), findsOneWidget);
      expect(find.text('Закрыть'), findsOneWidget);
      expect(find.text('Удалить'), findsOneWidget);

      await tester.tap(find.text('Частичная оплата'));
      await tester.pumpAndSettle();

      expect(find.text('Уже внесено'), findsOneWidget);
      expect(find.text('50 000 ₽'), findsOneWidget);
      expect(find.text('280 000 ₽'), findsOneWidget);

      await tester.ensureVisible(find.text('Редактировать'));
      await tester.tap(find.text('Редактировать'));
      await tester.pumpAndSettle();

      expect(find.textContaining('12.09.2026'), findsWidgets);
      expect(find.text('285 000 ₽'), findsOneWidget);
    },
  );
}
