import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/models/account.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/state/ledger_state.dart';

void main() {
  group('Account icon', () {
    test('round-trips a chosen icon through toMap/fromMap', () {
      const a = Account(
        id: 'x',
        name: 'My Wallet',
        sub: 'Cash · HKD',
        letter: 'M',
        color: '#3ad29f',
        bg: '#1f3a32',
        balance: 100,
        nature: AccountNature.asset,
        group: 'cashbank',
        icon: 'account_balance_wallet',
      );
      expect(Account.fromMap(a.toMap()).icon, 'account_balance_wallet');
    });

    test('defaults to null icon when none is chosen', () {
      const a = Account(
        id: 'x',
        name: 'No icon',
        sub: 'Cash · HKD',
        letter: 'N',
        color: '#3ad29f',
        bg: '#1f3a32',
        balance: 0,
        nature: AccountNature.asset,
      );
      expect(a.icon, isNull);
      expect(Account.fromMap(a.toMap()).icon, isNull);
    });
  });

  group('saveAccount with a chosen icon', () {
    test('adding an account stores the picked icon', () {
      final s = LedgerState.initial().copyWith(
        acctSheetOpen: true,
        editingAccountId: '',
        newName: 'DBS Savings',
        newType: 'Savings',
        newCurrency: 'HKD',
        newBalance: '5000',
        newIcon: 'savings',
      );
      final next = s.saveAccount();
      final added = next.accounts.firstWhere((a) => a.name == 'DBS Savings');
      expect(added.icon, 'savings');
    });

    test('a blank icon choice stores null (smart default applies)', () {
      final s = LedgerState.initial().copyWith(
        acctSheetOpen: true,
        newName: 'Plain Bank',
        newType: 'Debit',
        newCurrency: 'HKD',
        newBalance: '10',
        newIcon: '',
      );
      final next = s.saveAccount();
      final added = next.accounts.firstWhere((a) => a.name == 'Plain Bank');
      expect(added.icon, isNull);
    });

    test('editing an account updates its icon in place', () {
      final s = LedgerState.initial().copyWith(
        acctSheetOpen: true,
        editingAccountId: 'hsbc',
        newName: 'HSBC One',
        newBalance: '52100',
        newIcon: 'account_balance',
      );
      final next = s.saveAccount();
      expect(next.accountById('hsbc')!.icon, 'account_balance');
    });
  });

  group('clearing a chosen icon (back to Auto)', () {
    test('Account.copyWith(icon: null) clears the icon', () {
      const a = Account(
        id: 'x',
        name: 'N',
        sub: 'Cash · HKD',
        letter: 'N',
        color: '#fff',
        bg: '#000',
        balance: 0,
        nature: AccountNature.asset,
        icon: 'savings',
      );
      expect(a.copyWith(icon: null).icon, isNull);
      expect(a.copyWith(name: 'M').icon, 'savings'); // unchanged when not passed
    });

    test('editing a chosen icon back to Auto clears it', () {
      final withIcon = LedgerState.initial()
          .copyWith(
            acctSheetOpen: true,
            editingAccountId: 'hsbc',
            newName: 'HSBC One',
            newBalance: '52100',
            newIcon: 'account_balance',
          )
          .saveAccount();
      expect(withIcon.accountById('hsbc')!.icon, 'account_balance');

      final cleared = withIcon
          .copyWith(
            acctSheetOpen: true,
            editingAccountId: 'hsbc',
            newName: 'HSBC One',
            newBalance: '52100',
            newIcon: '',
          )
          .saveAccount();
      expect(cleared.accountById('hsbc')!.icon, isNull);
    });
  });

  group('editing a balance logs an adjustment', () {
    test('increasing a balance records an income adjustment', () {
      final base = LedgerState.initial();
      final before = base.accountById('hsbc')!.balance; // 52100
      final txnsBefore = base.transactions.length;
      final next = base
          .copyWith(
            acctSheetOpen: true,
            editingAccountId: 'hsbc',
            newName: 'HSBC One',
            newBalance: '60000',
          )
          .saveAccount();
      expect(next.accountById('hsbc')!.balance, 60000);
      expect(next.transactions.length, txnsBefore + 1);
      final adj = next.transactions.first;
      expect(adj.type, TxnType.income);
      expect(adj.amount, 60000 - before);
      expect(adj.acctId, 'hsbc');
      expect(adj.payee, 'Balance adjustment');
    });

    test('an unchanged balance logs nothing', () {
      final base = LedgerState.initial();
      final before = base.accountById('hsbc')!.balance;
      final next = base
          .copyWith(
            acctSheetOpen: true,
            editingAccountId: 'hsbc',
            newName: 'HSBC One',
            newBalance: before.toStringAsFixed(0),
          )
          .saveAccount();
      expect(next.transactions.length, base.transactions.length);
    });
  });
}
