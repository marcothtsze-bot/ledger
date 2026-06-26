import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/models/account.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/models/recurring.dart';
import 'package:ledger/models/txn.dart';

void main() {
  group('model serialization round-trips', () {
    test('Account (credit card) survives toMap/fromMap', () {
      const a = Account(
        id: 'citi',
        name: 'Citi Cash Back',
        sub: 'Credit · HKD',
        letter: 'C',
        color: '#b69bff',
        bg: '#2a2433',
        balance: -8420,
        nature: AccountNature.liability,
        group: 'credit',
        creditLimit: 80000,
        minPayment: 420,
      );
      final b = Account.fromMap(a.toMap());
      expect(b.id, a.id);
      expect(b.balance, a.balance);
      expect(b.nature, AccountNature.liability);
      expect(b.group, 'credit');
      expect(b.creditLimit, 80000);
      expect(b.minPayment, 420);
    });

    test('Txn keeps foreign note, type and date', () {
      final t = Txn(
        id: 3,
        type: TxnType.expense,
        amount: 375,
        payee: 'Amazon US',
        catId: 'shopping',
        acctId: 'citi',
        date: DateTime(2026, 6, 21),
        foreign: 'US\$48.00 @ 7.81',
      );
      final r = Txn.fromMap(t.toMap());
      expect(r.type, TxnType.expense);
      expect(r.amount, 375);
      expect(r.date, DateTime(2026, 6, 21));
      expect(r.foreign, 'US\$48.00 @ 7.81');
    });

    test('Recurring installment keeps total/paid', () {
      const r = Recurring(
        id: 'u1',
        name: 'MacBook',
        amount: 1500,
        freq: 'Installment',
        next: 'Jul 21',
        catId: 'shopping',
        kind: RecurringKind.installment,
        total: 12,
        paid: 1,
      );
      final back = Recurring.fromMap(r.toMap());
      expect(back.kind, RecurringKind.installment);
      expect(back.total, 12);
      expect(back.paid, 1);
    });

    test('copyWith replaces only the given field', () {
      const a = Account(
        id: 'hsbc',
        name: 'HSBC One',
        sub: 'Debit · HKD',
        letter: 'H',
        color: '#3ad29f',
        bg: '#1f3a32',
        balance: 52100,
        nature: AccountNature.asset,
      );
      final b = a.copyWith(balance: 60000);
      expect(b.balance, 60000);
      expect(b.name, 'HSBC One');
      expect(a.balance, 52100, reason: 'original is not mutated');
    });
  });
}
