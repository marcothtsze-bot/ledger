import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/state/ledger_state.dart';

void main() {
  final base = LedgerState.initial();

  group('edit account', () {
    test('updates balance and statement settings in place by id', () {
      final r = base
          .copyWith(
            editingAccountId: 'citi',
            newName: 'Standard Chartered',
            newBalance: '9000',
            newLimit: '90000',
            newStatementDay: '6',
            newDueDay: '26',
            newStatementBalance: '7000',
          )
          .saveAccount();
      final card = r.accountById('citi')!;
      expect(card.balance, -9000, reason: 'liability balance stays negative');
      expect(card.creditLimit, 90000);
      expect(card.statementDay, 6);
      expect(card.dueDay, 26);
      expect(card.statementBalance, 7000);
      expect(r.acctSheetOpen, false);
      expect(r.editingAccountId, '');
      expect(r.toast, 'Account updated');
      expect(
        r.accounts.length,
        base.accounts.length,
        reason: 'no account added',
      );
    });

    test('editing an asset keeps a positive balance', () {
      final r = base
          .copyWith(
            editingAccountId: 'hsbc',
            newName: 'HSBC One',
            newBalance: '60000',
          )
          .saveAccount();
      expect(r.accountById('hsbc')!.balance, 60000);
    });

    test('blank name is rejected', () {
      final r = base
          .copyWith(editingAccountId: 'citi', newName: '  ')
          .saveAccount();
      expect(r.newInvalid, true);
    });

    test('day inputs clamp to 1–31', () {
      final r = base
          .copyWith(
            editingAccountId: 'citi',
            newName: 'SC',
            newStatementDay: '99',
            newDueDay: '0',
          )
          .saveAccount();
      final card = r.accountById('citi')!;
      expect(card.statementDay, 31);
      expect(card.dueDay, 1);
    });

    test('adding a credit account captures statement settings', () {
      final r = base
          .copyWith(
            newName: 'AmEx',
            newType: 'Credit',
            newBalance: '3000',
            newLimit: '50000',
            newStatementDay: '15',
            newDueDay: '3',
            newStatementBalance: '1200',
          )
          .saveAccount();
      final card = r.accounts.last;
      expect(card.name, 'AmEx');
      expect(card.balance, -3000);
      expect(card.creditLimit, 50000);
      expect(card.statementDay, 15);
      expect(card.dueDay, 3);
      expect(card.statementBalance, 1200);
    });
  });
}
