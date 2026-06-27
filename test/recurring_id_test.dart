import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/models/account.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/models/recurring.dart';
import 'package:ledger/state/ledger_state.dart';

/// Duplicate recurring ids (the old `u{txnId}` scheme) made the later item
/// unmanageable and double-counted it on card statements. Ids are now healed on
/// load and the statement forecast is keyed by position, not id.
void main() {
  Recurring rec(
    String id,
    String name,
    double amt,
    RecurringKind kind,
    String acct, {
    int? total,
    DateTime? next,
  }) =>
      Recurring(
        id: id,
        name: name,
        amount: amt,
        freq: kind == RecurringKind.installment ? 'Installment' : 'Monthly',
        next: 'x',
        catId: 'loan',
        kind: kind,
        total: total,
        paid: total != null ? 1 : null,
        accountId: acct,
        nextDate: next,
      );

  test('fromSnapshot heals duplicate recurring ids, keeping both items', () {
    final snap = LedgerState.initial().copyWith(
      recurring: [
        rec('u7', 'Home Fee', 10000, RecurringKind.sub, 'a0'),
        rec('u7', 'Education', 1300, RecurringKind.sub, 'a0'),
      ],
    ).toSnapshot();

    final healed = LedgerState.fromSnapshot(snap).recurring;
    final ids = healed.map((r) => r.id).toList();
    expect(ids.toSet().length, ids.length); // every id unique now
    expect(healed.map((r) => r.name).toSet(), {'Home Fee', 'Education'});
  });

  test('upcomingStatements does not collapse or double-count a shared id', () {
    const card = Account(
      id: 'card',
      name: 'EveryMiles',
      sub: '',
      letter: 'E',
      color: '#fff',
      bg: '#000',
      balance: 0,
      nature: AccountNature.liability,
      group: 'credit',
      creditLimit: 100000,
      statementDay: 10,
      dueDay: 1,
    );
    final now = DateTime(2026, 6, 20);
    final next = DateTime(2026, 7, 11); // lands on the Aug 10 statement
    final s = LedgerState.empty().copyWith(
      accounts: [card],
      recurring: [
        rec('u9', 'Loan A', 1000, RecurringKind.installment, 'card',
            total: 5, next: next),
        rec('u9', 'Loan B', 2000, RecurringKind.installment, 'card',
            total: 5, next: next),
      ],
    );

    final first = s.upcomingStatements('card', now).first;
    expect(first.charges.length, 2); // two distinct charges, not collapsed
    expect(first.charges.every((c) => c.count == 1), isTrue); // not doubled
    expect(first.charges.map((c) => c.source.name).toSet(), {'Loan A', 'Loan B'});
  });

  // Marco's real shape: a stray "Loan" sub duplicating the "Loan" installment,
  // plus Home Fee/Education that merely collided ids (NOT duplicates).
  LedgerState marcoLike() => LedgerState.empty().copyWith(
        recurring: [
          rec('u9', 'Loan', 1662, RecurringKind.installment, 'a4', total: 5),
          rec('u9-2', 'Loan', 1662, RecurringKind.sub, 'a4'), // the stray
          rec('u8', 'Loan', 4398, RecurringKind.installment, 'a4', total: 7),
          rec('u7', 'Home Fee', 10000, RecurringKind.sub, 'a0'),
          rec('u7-2', 'Education', 1300, RecurringKind.sub, 'a0'),
        ],
      );

  test('detects only the redundant sub as a duplicate', () {
    final s = marcoLike();
    expect(s.duplicateRecurringCount, 1); // only the stray Loan sub
  });

  test('merge drops the stray sub, keeps the installment + everything else', () {
    final merged = marcoLike().mergeDuplicateRecurring();
    expect(merged.recurring.length, 4); // 5 → 4
    final loan1662 = merged.recurring.firstWhere((r) => r.amount == 1662);
    expect(loan1662.kind, RecurringKind.installment); // kept the real plan
    expect(merged.recurring.any((r) => r.name == 'Home Fee'), isTrue);
    expect(merged.recurring.any((r) => r.name == 'Education'), isTrue);
    expect(merged.recurring.any((r) => r.amount == 4398), isTrue);
  });
}
