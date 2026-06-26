import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/models/txn.dart';
import 'package:ledger/state/ledger_state.dart';

void main() {
  group('activity filters', () {
    final base = LedgerState.initial().copyWith(
      transactions: [
        Txn(
          id: 1,
          type: TxnType.expense,
          amount: 10,
          payee: 'a',
          catId: 'dining',
          acctId: 'hsbc',
          date: DateTime(2026, 6, 10),
        ),
        Txn(
          id: 2,
          type: TxnType.expense,
          amount: 20,
          payee: 'b',
          catId: 'transport',
          acctId: 'citi',
          date: DateTime(2026, 6, 10),
        ),
        Txn(
          id: 3,
          type: TxnType.income,
          amount: 30,
          payee: 'c',
          catId: 'salary',
          acctId: 'hsbc',
          date: DateTime(2026, 6, 10),
        ),
      ],
    );

    Set<int> ids(LedgerState s) =>
        s.activityGroups.expand((g) => g.items).map((t) => t.id).toSet();

    test('no filters returns everything', () {
      expect(ids(base), {1, 2, 3});
      expect(base.hasActiveFilters, isFalse);
    });

    test('filters by account', () {
      final s = base.copyWith(filterAccountId: 'hsbc');
      expect(ids(s), {1, 3});
      expect(s.hasActiveFilters, isTrue);
    });

    test('filters by category', () {
      expect(ids(base.copyWith(filterCategoryId: 'dining')), {1});
    });

    test('filters by type', () {
      expect(ids(base.copyWith(filterType: 'income')), {3});
    });

    test('combines filters and clears them', () {
      final s = base.copyWith(filterAccountId: 'hsbc', filterType: 'expense');
      expect(ids(s), {1});
      expect(s.clearFilters().hasActiveFilters, isFalse);
      expect(ids(s.clearFilters()), {1, 2, 3});
    });
  });
}
