import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/core/fx.dart';
import 'package:ledger/models/account.dart';
import 'package:ledger/models/enums.dart';

void main() {
  group('fx defaults', () {
    test('base currency is HKD and converts 1:1', () {
      expect(kBaseCurrency, 'HKD');
      expect(defaultRateToHkd('HKD'), 1.0);
    });

    test('known currencies have a default rate (case-insensitive)', () {
      expect(defaultRateToHkd('USD'), 7.8);
      expect(defaultRateToHkd('jpy'), 0.052);
    });

    test('an unknown currency falls back to 1:1, never silently zeroed', () {
      expect(defaultRateToHkd('XYZ'), 1.0);
    });
  });

  group('Account currency conversion', () {
    Account acct({
      required String currency,
      double? fxRate,
      double balance = 0,
    }) => Account(
      id: 'a',
      name: 'A',
      sub: '',
      letter: 'A',
      color: '#fff',
      bg: '#000',
      currency: currency,
      fxRate: fxRate,
      balance: balance,
      nature: AccountNature.asset,
    );

    test('an HKD account is always 1:1, even with a stray rate', () {
      final a = acct(currency: 'HKD', fxRate: 99, balance: 1000);
      expect(a.rateToHkd, 1.0);
      expect(a.balanceHkd, 1000);
    });

    test('a foreign account with no rate uses the default table', () {
      final a = acct(currency: 'JPY', balance: 100000);
      expect(a.rateToHkd, 0.052);
      expect(a.balanceHkd, closeTo(5200, 1e-6));
    });

    test('an explicit per-account rate overrides the default', () {
      final a = acct(currency: 'JPY', fxRate: 0.05, balance: 100000);
      expect(a.balanceHkd, closeTo(5000, 1e-6));
    });
  });
}
