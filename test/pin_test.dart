import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/models/account.dart';
import 'package:ledger/state/ledger_state.dart';

void main() {
  final base = LedgerState.initial();

  group('pin to home', () {
    test('seed pins HSBC and Standard Chartered', () {
      final ids = base.pinnedAccounts.map((a) => a.id).toList();
      expect(ids, containsAll(['hsbc', 'citi']));
      expect(base.pinnedAccounts.length, 2);
    });

    test('pinning a third works; a fourth is rejected', () {
      final s = base.togglePin('wise');
      expect(s.accountById('wise')!.pinned, true);
      expect(s.pinnedAccounts.length, 3);
      expect(s.toast, 'Pinned to Home');

      final s2 = s.togglePin('cash');
      expect(s2.accountById('cash')!.pinned, false);
      expect(s2.pinnedAccounts.length, 3);
      expect(s2.toast, 'You can pin up to 3 accounts');
    });

    test('unpinning frees a slot', () {
      final s = base.togglePin('hsbc');
      expect(s.accountById('hsbc')!.pinned, false);
      expect(s.pinnedAccounts.length, 1);
      expect(s.toast, 'Unpinned from Home');
    });

    test('pinned survives toMap/fromMap', () {
      final a = base.accountById('hsbc')!;
      expect(Account.fromMap(a.toMap()).pinned, true);
    });
  });
}
