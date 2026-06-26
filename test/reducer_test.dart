import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/state/ledger_state.dart';

void main() {
  final base = LedgerState.initial();

  group('derivations', () {
    test('net worth sums all balances', () {
      // 52100 − 8420 + 9680 + 2150 + 218400 + 208390
      expect(base.netWorth, 482300);
    });

    test('assets and liabilities split by sign', () {
      expect(base.assets, 490720);
      expect(base.liabilities, 8420);
    });

    test('recurring monthly sums the seeded subscriptions', () {
      expect(base.recurringMonthly, 713); // 78 + 58 + 78 + 499
    });
  });

  group('keypad pressKey', () {
    test('replaces a lone zero and appends digits', () {
      expect(base.copyWith(amount: '').pressKey('5').amount, '5');
      expect(base.copyWith(amount: '0').pressKey('5').amount, '5');
      expect(base.copyWith(amount: '5').pressKey('0').amount, '50');
    });

    test('allows a single decimal point and max two decimals', () {
      var s = base.copyWith(amount: '5').pressKey('.');
      expect(s.amount, '5.');
      s = s.pressKey('.'); // ignored — already has a dot
      expect(s.amount, '5.');
      s = s.pressKey('0').pressKey('0');
      expect(s.amount, '5.00');
      s = s.pressKey('1'); // ignored — already two decimals
      expect(s.amount, '5.00');
    });

    test('leading dot becomes 0.', () {
      expect(base.copyWith(amount: '').pressKey('.').amount, '0.');
    });

    test('backspace trims one character and clears invalid', () {
      final s = base.copyWith(amount: '12', invalid: true).pressKey('del');
      expect(s.amount, '1');
      expect(s.invalid, false);
    });
  });

  group('save transaction', () {
    test('expense debits the account and grows expense total', () {
      final s = base.copyWith(
        sheetOpen: true,
        txnType: TxnType.expense,
        accountId: 'hsbc',
        categoryId: 'dining',
        amount: '100',
        payee: 'Lunch',
      );
      final r = s.save(close: true);
      expect(r.transactions.first.payee, 'Lunch');
      expect(r.transactions.first.amount, 100);
      expect(r.accountById('hsbc')!.balance, 52000); // 52100 − 100
      expect(r.expenseMonth, 18800); // 18700 + 100
      expect(r.tab, AppTab.activity);
      expect(r.sheetOpen, false);
      expect(r.toast, 'Transaction saved');
    });

    test('blank payee defaults to the category name', () {
      final r = base
          .copyWith(
            txnType: TxnType.expense,
            categoryId: 'groceries',
            amount: '50',
            payee: '',
          )
          .save(close: true);
      expect(r.transactions.first.payee, 'Groceries');
    });

    test('income credits the account and grows income total', () {
      final r = base
          .copyWith(txnType: TxnType.income, accountId: 'hsbc', amount: '1000')
          .save(close: true);
      expect(r.accountById('hsbc')!.balance, 53100);
      expect(r.incomeMonth, 25100);
    });

    test('transfer moves money between two accounts only', () {
      final r = base
          .copyWith(
            txnType: TxnType.transfer,
            accountId: 'citi',
            toAccountId: 'hsbc',
            amount: '500',
          )
          .save(close: true);
      expect(r.accountById('citi')!.balance, -8920); // −8420 − 500
      expect(r.accountById('hsbc')!.balance, 52600); // 52100 + 500
      expect(r.incomeMonth, base.incomeMonth);
      expect(r.expenseMonth, base.expenseMonth);
    });

    test('installment splits the amount and starts a plan', () {
      final r = base
          .copyWith(
            txnType: TxnType.expense,
            accountId: 'citi',
            categoryId: 'shopping',
            amount: '1200',
            installMonths: 6,
            repeat: RepeatMode.installment,
          )
          .save(close: true);
      expect(
        r.transactions.first.amount,
        200,
        reason: '1200 / 6 logged per month',
      );
      expect(r.accountById('citi')!.balance, -8620); // −8420 − 200
      expect(r.installments.length, 1);
      expect(r.installments.first.total, 6);
      expect(r.installments.first.paid, 1);
      expect(r.installments.first.amount, 200);
      expect(r.toast, 'Installment plan started');
    });

    test('weekly/monthly repeat creates a subscription', () {
      final r = base
          .copyWith(
            txnType: TxnType.expense,
            amount: '120',
            payee: 'Disney+',
            repeat: RepeatMode.monthly,
          )
          .save(close: true);
      expect(
        r.subscriptions.any((x) => x.name == 'Disney+' && x.freq == 'Monthly'),
        isTrue,
      );
    });

    test('non-positive amount is rejected as invalid, nothing added', () {
      final r = base.copyWith(amount: '').save(close: true);
      expect(r.invalid, true);
      expect(r.transactions.length, base.transactions.length);
    });

    test('"+ another" keeps the sheet open and resets the draft', () {
      final r = base
          .copyWith(
            sheetOpen: true,
            amount: '80',
            payee: 'Coffee',
            txnType: TxnType.expense,
          )
          .save(close: false);
      expect(r.sheetOpen, true);
      expect(r.amount, '');
      expect(r.payee, '');
      expect(r.tab, base.tab);
    });
  });

  group('save account', () {
    test('asset account joins cash & bank with a positive balance', () {
      final r = base
          .copyWith(
            newName: 'DBS Savings',
            newType: 'Savings',
            newCurrency: 'HKD',
            newBalance: '5000',
          )
          .saveAccount();
      final added = r.accounts.last;
      expect(added.name, 'DBS Savings');
      expect(added.group, 'cashbank');
      expect(added.balance, 5000);
      expect(added.nature, AccountNature.asset);
      expect(r.acctSheetOpen, false);
      expect(r.toast, 'Account added');
    });

    test('credit/loan store a negative balance in the credit group', () {
      final r = base
          .copyWith(newName: 'AmEx', newType: 'Credit', newBalance: '3000')
          .saveAccount();
      final added = r.accounts.last;
      expect(added.balance, -3000);
      expect(added.group, 'credit');
      expect(added.nature, AccountNature.liability);
    });

    test('investment type lands in the invest group', () {
      final r = base
          .copyWith(
            newName: 'IBKR 2',
            newType: 'Investment',
            newBalance: '10000',
          )
          .saveAccount();
      expect(r.accounts.last.group, 'invest');
    });

    test('blank name is rejected and nothing is added', () {
      final r = base.copyWith(newName: '  ').saveAccount();
      expect(r.newInvalid, true);
      expect(r.accounts.length, base.accounts.length);
    });
  });

  group('activity search + grouping', () {
    test('no query groups all five seeded transactions by day', () {
      final g = base.activityGroups;
      expect(g.length, 2);
      expect(g.first.items.length, 3, reason: 'today: 3 txns');
      expect(g.first.total, -675); // −268 − 32 − 375
      expect(g[1].items.length, 2, reason: 'yesterday: 2 txns');
      expect(g[1].total, 23458); // 24100 − 642
      expect(g.first.date.isAfter(g[1].date), isTrue, reason: 'newest first');
    });

    test('matches payee', () {
      final g = base.copyWith(search: 'mtr').activityGroups;
      expect(g.length, 1);
      expect(g.first.items.single.payee, 'MTR');
    });

    test('matches category name', () {
      final g = base.copyWith(search: 'dining').activityGroups;
      expect(g.first.items.single.payee, 'Tsui Wah');
    });

    test('no matches sets the empty-state flag', () {
      final s = base.copyWith(search: 'zzz');
      expect(s.activityGroups, isEmpty);
      expect(s.noSearchResults, true);
    });
  });
}
