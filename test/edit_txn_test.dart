import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/state/ledger_state.dart';

void main() {
  final base = LedgerState.initial();

  group('edit transaction', () {
    test('changing an expense amount reverses old and applies new', () {
      // Seed txn 1: expense 268 (Tsui Wah, dining, hsbc).
      final r = base
          .copyWith(
            editingTxnId: 1,
            txnType: TxnType.expense,
            accountId: 'hsbc',
            categoryId: 'dining',
            amount: '300',
            payee: 'Tsui Wah',
          )
          .save(close: true);
      final tx = r.transactions.firstWhere((t) => t.id == 1);
      expect(tx.amount, 300);
      expect(
        r.accountById('hsbc')!.balance,
        52100 + 268 - 300,
        reason: 'net −32',
      );
      expect(r.expenseMonth, base.expenseMonth + 32);
      expect(r.editingTxnId, 0);
      expect(r.sheetOpen, false);
      expect(r.toast, 'Transaction updated');
      expect(r.transactions.length, base.transactions.length);
    });

    test('changing type from expense to income flips the account effect', () {
      // txn 1 expense 268 on hsbc -> income 268 on hsbc.
      final r = base
          .copyWith(
            editingTxnId: 1,
            txnType: TxnType.income,
            accountId: 'hsbc',
            amount: '268',
            payee: 'Refund',
          )
          .save(close: true);
      // reverse expense (+268) then apply income (+268) => +536
      expect(r.accountById('hsbc')!.balance, 52100 + 268 + 268);
      expect(r.expenseMonth, base.expenseMonth - 268);
      expect(r.incomeMonth, base.incomeMonth + 268);
    });

    test('editing a transfer moves both sides correctly', () {
      final created = base
          .copyWith(
            txnType: TxnType.transfer,
            accountId: 'citi',
            toAccountId: 'hsbc',
            amount: '500',
          )
          .save(close: true);
      final txId = created.transactions.first.id;
      final edited = created
          .copyWith(
            editingTxnId: txId,
            txnType: TxnType.transfer,
            accountId: 'citi',
            toAccountId: 'hsbc',
            amount: '800',
          )
          .save(close: true);
      expect(edited.accountById('citi')!.balance, -9220);
      expect(edited.accountById('hsbc')!.balance, 52900);
    });
  });

  group('delete transaction', () {
    test('deleting an expense reverses its effect', () {
      final r = base.deleteTxn(1);
      expect(r.accountById('hsbc')!.balance, 52100 + 268);
      expect(r.expenseMonth, base.expenseMonth - 268);
      expect(r.transactions.any((t) => t.id == 1), isFalse);
      expect(r.toast, 'Transaction deleted');
    });

    test('deleting income reverses its effect', () {
      // Seed txn 4: income 24100 on hsbc.
      final r = base.deleteTxn(4);
      expect(r.accountById('hsbc')!.balance, 52100 - 24100);
      expect(r.incomeMonth, base.incomeMonth - 24100);
    });
  });
}
