import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/data/ledger_repository.dart';
import 'package:ledger/data/seed.dart';
import 'package:ledger/models/account.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/state/ledger_state.dart';

/// Regression: accounts must stay independently addressable. The old
/// `a{count}` id scheme reused an id after a delete, so two accounts shared one
/// and tapping the later account opened the earlier.
void main() {
  Account acct(String id, String name) => Account(
    id: id,
    name: name,
    sub: '',
    letter: name[0],
    color: '#fff',
    bg: '#000',
    balance: 0,
    nature: AccountNature.asset,
    group: 'cashbank',
  );

  group('new account ids never collide', () {
    test('a fresh id is chosen even when the count would repeat one', () {
      // After a delete you can be left with one account already named 'a1'.
      final s = LedgerState.empty().copyWith(accounts: [acct('a1', 'Existing')]);
      final r = s
          .copyWith(newName: 'New Bank', newType: 'Debit', newBalance: '0')
          .saveAccount();

      expect(r.accounts.length, 2);
      expect(r.accounts.last.id, isNot('a1'), reason: 'old scheme reused a1');
      final ids = r.accounts.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'all ids unique');
    });
  });

  group('fromSnapshot heals duplicate ids', () {
    test('collided accounts become independently addressable', () {
      final snap = LedgerSnapshot(
        accounts: [
          acct('a1', 'Bank B'),
          acct('a1', 'Bank C'), // duplicate id from the old bug
          acct('a2', 'Bank D'),
        ],
        transactions: const [],
        recurring: const [],
        categories: kCategories,
        budgets: const {},
        incomeMonth: 0,
        expenseMonth: 0,
      );

      final s = LedgerState.fromSnapshot(snap);

      expect(s.accounts.length, 3, reason: 'no account dropped');
      final ids = s.accounts.map((a) => a.id).toList();
      expect(ids.toSet().length, 3, reason: 'every id is now unique');
      expect(s.accounts[0].id, 'a1', reason: 'first occurrence keeps its id');
      expect(s.accounts[1].id, isNot('a1'), reason: 'duplicate reassigned');
      // The previously-shadowed account can now be opened on its own.
      expect(s.accountById(s.accounts[1].id)!.name, 'Bank C');
    });
  });
}
