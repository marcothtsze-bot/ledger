import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/state/ledger_state.dart';

void main() {
  final base = LedgerState.initial();

  group('pay statement', () {
    test('pays the statement from the chosen account', () {
      // Standard Chartered (citi): statement 6420, balance −8420. Pay from HSBC.
      final r = base.copyWith(payCardId: 'citi').payStatement('hsbc');
      expect(r.accountById('hsbc')!.balance, 52100 - 6420);
      expect(r.accountById('citi')!.balance, -8420 + 6420);
      expect(r.accountById('citi')!.statementBalance, 0);
      expect(r.payCardId, '');
      expect(r.toast, 'Statement marked paid');
    });

    test('net worth is unchanged by a payment', () {
      final before = base.netWorth;
      final r = base.copyWith(payCardId: 'citi').payStatement('hsbc');
      expect(r.netWorth, before);
    });

    test('records a transfer transaction for the payment', () {
      final r = base.copyWith(payCardId: 'citi').payStatement('hsbc');
      final tx = r.transactions.first;
      expect(tx.type, TxnType.transfer);
      expect(tx.amount, 6420);
      expect(tx.acctId, 'hsbc');
      expect(tx.payee, contains('payment'));
    });

    test('paying with nothing due is a no-op that just closes', () {
      final r = base.copyWith(payCardId: 'hsbc').payStatement('cash');
      expect(r.payCardId, '');
      expect(r.transactions.length, base.transactions.length);
    });

    test('payableAccounts are the cash/bank assets only', () {
      final ids = base.payableAccounts.map((a) => a.id).toSet();
      expect(ids, containsAll(['hsbc', 'wise', 'cash']));
      expect(ids, isNot(contains('citi')), reason: 'liability');
      expect(ids, isNot(contains('ib')), reason: 'investment');
    });
  });
}
