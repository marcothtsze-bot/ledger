import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/data/in_memory_repository.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/models/recurring.dart';
import 'package:ledger/models/txn.dart';
import 'package:ledger/state/ledger_notifier.dart';
import 'package:ledger/state/ledger_state.dart';

/// The four roadmap features: cash-runway forecast, Activity month flow,
/// transaction notes, and payee→category auto-fill.
void main() {
  final base = LedgerState.initial();

  Txn tx(int id, TxnType type, double amt, String payee, String cat,
          String acct, DateTime date) =>
      Txn(
        id: id,
        type: type,
        amount: amt,
        payee: payee,
        catId: cat,
        acctId: acct,
        date: date,
      );

  group('cash-runway forecast', () {
    final now = DateTime(2026, 6, 20); // citi statementBalance 6420, dueDay 25
    final s = base.copyWith(
      recurring: [
        Recurring(
          id: 'sub',
          name: 'Netflix',
          amount: 78,
          freq: 'Monthly',
          next: 'x',
          catId: 'subs',
          kind: RecurringKind.sub,
          accountId: 'hsbc', // paid from cash
          nextDate: DateTime(2026, 6, 25),
        ),
        Recurring(
          id: 'cardsub',
          name: 'Spotify',
          amount: 58,
          freq: 'Monthly',
          next: 'x',
          catId: 'subs',
          kind: RecurringKind.sub,
          accountId: 'citi', // billed to the card → not a direct cash bill
          nextDate: DateTime(2026, 6, 26),
        ),
      ],
    );

    test('lists cash-paid recurring + card statement due, not card-billed', () {
      final f = s.cashForecast(now, days: 30);
      final names = f.obligations.map((o) => o.name).toSet();
      expect(names.contains('Netflix'), isTrue); // cash-paid sub
      expect(names.contains('Standard Chartered statement'), isTrue); // citi
      expect(names.contains('Spotify'), isFalse); // card-billed → via statement
    });

    test('cashNow is spendable cash; totalOut sums the obligations', () {
      final f = s.cashForecast(now, days: 30);
      expect(f.cashNow, s.spendableCash);
      expect(f.totalOut, 78 + 6420); // Netflix + citi statement
      expect(f.cashAfter, f.cashNow - 6498);
    });

    test('a weekly cash-paid item is counted every week in the window', () {
      final weekly = base.copyWith(
        recurring: [
          Recurring(
            id: 'w',
            name: 'Gym',
            amount: 50,
            freq: 'Weekly',
            next: 'x',
            catId: 'health',
            kind: RecurringKind.sub,
            accountId: 'hsbc',
            nextDate: DateTime(2026, 6, 22),
          ),
        ],
      );
      final gym = weekly
          .cashForecast(now, days: 30)
          .obligations
          .where((o) => o.name == 'Gym')
          .toList();
      expect(gym.length, greaterThanOrEqualTo(4)); // ~5 weeks, not just 1
    });
  });

  group('Activity month flow + scope', () {
    final s = base.copyWith(
      filterMonth: DateTime(2026, 6),
      transactions: [
        tx(1, TxnType.income, 1000, 'Salary', 'salary', 'hsbc',
            DateTime(2026, 6, 5)),
        tx(2, TxnType.expense, 200, 'Lunch', 'dining', 'hsbc',
            DateTime(2026, 6, 6)),
        tx(3, TxnType.expense, 999, 'Lunch', 'dining', 'hsbc',
            DateTime(2026, 5, 10)),
      ],
    );

    test('monthFlow totals income/expense for the given month', () {
      expect(s.monthFlow(DateTime(2026, 6)).income, 1000);
      expect(s.monthFlow(DateTime(2026, 6)).expense, 200);
      expect(s.monthFlow(DateTime(2026, 5)).expense, 999);
    });

    test('activityGroups scope to filterMonth, but search spans all', () {
      final scoped =
          s.activityGroups.expand((g) => g.items).map((t) => t.id).toSet();
      expect(scoped, {1, 2}); // June only

      final searched = s
          .copyWith(search: 'lunch')
          .activityGroups
          .expand((g) => g.items)
          .map((t) => t.id)
          .toSet();
      expect(searched, {2, 3}); // both Lunches, across May + June
    });
  });

  group('transaction notes', () {
    test('Txn.note round-trips through toMap/fromMap', () {
      final t = tx(1, TxnType.expense, 50, 'X', 'dining', 'hsbc',
              DateTime(2026, 6, 1))
          .copyWith(note: 'reimbursable');
      expect(Txn.fromMap(t.toMap()).note, 'reimbursable');
    });

    test('save() stores the drafted note and resets it', () {
      final r = base
          .copyWith(
            txnType: TxnType.expense,
            accountId: 'hsbc',
            categoryId: 'dining',
            amount: '50',
            note: 'team lunch',
          )
          .save(close: true);
      expect(r.transactions.first.note, 'team lunch');
      expect(r.note, '', reason: 'draft note clears after saving');
    });
  });

  group('payee → category auto-fill', () {
    final s = base.copyWith(
      transactions: [
        tx(1, TxnType.expense, 50, 'Starbucks', 'coffee', 'hsbc',
            DateTime(2026, 6, 1)),
        tx(2, TxnType.expense, 60, 'Starbucks', 'coffee', 'hsbc',
            DateTime(2026, 6, 2)),
        tx(3, TxnType.expense, 70, 'Starbucks', 'dining', 'hsbc',
            DateTime(2026, 6, 3)),
      ],
    );

    test('suggests the most-used category for a known payee', () {
      expect(s.suggestCategoryForPayee('starbucks'), 'coffee'); // 2 vs 1
    });

    test('returns null for an unknown payee', () {
      expect(s.suggestCategoryForPayee('Nowhere'), isNull);
      expect(s.suggestCategoryForPayee(''), isNull);
    });

    test('auto-fills on payee, but never overrides a manual category pick',
        () async {
      final seed = base.copyWith(
        transactions: [
          tx(1, TxnType.expense, 50, 'Starbucks', 'coffee', 'hsbc',
              DateTime(2026, 6, 1)),
        ],
      ).toSnapshot();
      final container = ProviderContainer(
        overrides: [
          ledgerRepositoryProvider
              .overrideWithValue(InMemoryLedgerRepository(seed)),
        ],
      );
      addTearDown(container.dispose);
      container.read(ledgerProvider); // trigger build + async hydrate
      for (var i = 0;
          i < 5 && container.read(ledgerProvider).transactions.isEmpty;
          i++) {
        await Future<void>.delayed(Duration.zero);
      }
      final n = container.read(ledgerProvider.notifier);

      // Typing a known payee preselects its usual category.
      n.openSheet();
      n.setPayee('Starbucks');
      expect(container.read(ledgerProvider).categoryId, 'coffee');

      // But a manual pick is sticky — re-entering the payee won't clobber it.
      n.openSheet();
      n.pickCategory('groceries');
      n.setPayee('Starbucks');
      expect(container.read(ledgerProvider).categoryId, 'groceries');
    });
  });
}
