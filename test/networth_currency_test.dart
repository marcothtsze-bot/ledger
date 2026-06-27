import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/models/account.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/models/txn.dart';
import 'package:ledger/state/ledger_state.dart';

/// Multi-currency aggregation: a JPY/USD account must be converted to HKD
/// before it lands in any total, not counted one-for-one.
void main() {
  Account acct(String id, String currency, double balance, {double? fxRate}) =>
      Account(
        id: id,
        name: id,
        sub: '',
        letter: id[0],
        color: '#fff',
        bg: '#000',
        currency: currency,
        fxRate: fxRate,
        balance: balance,
        nature: balance < 0 ? AccountNature.liability : AccountNature.asset,
      );

  LedgerState withAccounts(List<Account> a) =>
      LedgerState.empty().copyWith(accounts: a);

  group('multi-currency net worth', () {
    test('a JPY account is converted, not counted as HKD', () {
      final s = withAccounts([
        acct('hk', 'HKD', 10000),
        acct('jp', 'JPY', 100000, fxRate: 0.05), // = HK$5,000
      ]);
      expect(s.netWorth, closeTo(15000, 1e-6)); // not 110,000
    });

    test('assets and liabilities are both expressed in HKD', () {
      final s = withAccounts([
        acct('us', 'USD', 1000, fxRate: 7.8), // HK$7,800 asset
        acct('card', 'HKD', -2000), // HK$2,000 liability
      ]);
      expect(s.assets, closeTo(7800, 1e-6));
      expect(s.liabilities, closeTo(2000, 1e-6));
      expect(s.netWorth, closeTo(5800, 1e-6));
    });

    test('a foreign account with no explicit rate uses the default table', () {
      final s = withAccounts([acct('jp', 'JPY', 100000)]); // 0.052 default
      expect(s.netWorth, closeTo(5200, 1e-6));
    });
  });

  group('month totals convert foreign transactions', () {
    test('an expense on a JPY account adds HKD to the month total', () {
      final s = LedgerState.empty().copyWith(
        accounts: [acct('jp', 'JPY', 100000, fxRate: 0.05)],
        accountId: 'jp',
        categoryId: 'dining',
        txnType: TxnType.expense,
        amount: '1000', // ¥1,000 = HK$50
      );
      final r = s.save(close: true);
      expect(r.expenseMonth, closeTo(50, 1e-6)); // not 1,000
      // The stored balance stays in the account's own currency.
      expect(r.accountById('jp')!.balance, 99000);
    });

    test('deleting a foreign transaction reverses the HKD it added', () {
      final saved = LedgerState.empty()
          .copyWith(
            accounts: [acct('jp', 'JPY', 100000, fxRate: 0.05)],
            accountId: 'jp',
            categoryId: 'dining',
            txnType: TxnType.expense,
            amount: '1000',
          )
          .save(close: true);
      final id = saved.transactions.first.id;
      final after = saved.deleteTxn(id);
      expect(after.expenseMonth, closeTo(0, 1e-6));
    });
  });

  group('activity day totals are in HKD', () {
    test('a foreign income is converted in its day group total', () {
      final s = withAccounts([acct('jp', 'JPY', 0, fxRate: 0.05)]).copyWith(
        transactions: [
          Txn(
            id: 1,
            type: TxnType.income,
            amount: 200000, // ¥200,000 = HK$10,000
            payee: 'Tokyo client',
            catId: 'salary',
            acctId: 'jp',
            date: DateTime(2026, 6, 10),
          ),
        ],
      );
      expect(s.activityGroups.single.total, closeTo(10000, 1e-6));
    });
  });
}
