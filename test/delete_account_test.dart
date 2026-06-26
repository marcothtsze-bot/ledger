import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/state/ledger_state.dart';

void main() {
  final base = LedgerState.initial();

  group('delete account', () {
    test('removes account, its transactions, and adjusts month totals', () {
      // HSBC owns txns 1 (expense 268), 4 (income 24100), 5 (expense 642).
      final r = base.deleteAccount('hsbc');
      expect(r.accountById('hsbc'), isNull);
      expect(r.accounts.length, base.accounts.length - 1);
      expect(r.transactions.any((t) => t.acctId == 'hsbc'), isFalse);
      expect(r.expenseMonth, base.expenseMonth - 268 - 642);
      expect(r.incomeMonth, base.incomeMonth - 24100);
      expect(r.toast, 'Account deleted');
    });

    test('clears overlay + draft references to the deleted account', () {
      final s = base.copyWith(
        overlay: LedgerOverlay.account,
        overlayAcct: 'citi',
        accountId: 'citi',
        payCardId: 'citi',
      );
      final r = s.deleteAccount('citi');
      expect(r.overlay, LedgerOverlay.none);
      expect(r.overlayAcct, '');
      expect(r.accountId, isNot('citi'));
      expect(r.payCardId, '');
    });
  });
}
