import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/models/txn.dart';
import 'package:ledger/state/ledger_state.dart';
import 'package:ledger/view/txn_view.dart';

void main() {
  test('txnRowData carries the transaction date for reconciling', () {
    final t = Txn(
      id: 99,
      type: TxnType.expense,
      amount: 210,
      payee: 'Smartone',
      catId: 'phone',
      acctId: 'citi',
      date: DateTime(2026, 6, 18),
    );
    expect(txnRowData(LedgerState.initial(), t).date, '18 Jun 2026');
  });
}
