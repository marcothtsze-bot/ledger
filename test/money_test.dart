import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/core/money.dart';

void main() {
  group('money formatting', () {
    test('groups thousands with commas', () {
      expect(groupThousands(0), '0');
      expect(groupThousands(999), '999');
      expect(groupThousands(1234567), '1,234,567');
    });

    test('fmtAmount takes absolute value and rounds', () {
      expect(fmtAmount(-8420), '8,420');
      expect(fmtAmount(2.4), '2');
      expect(fmtAmount(2.6), '3');
    });

    test('hk prefixes HK\$', () {
      expect(hk(52100), r'HK$52,100');
    });

    test('signedHk uses the U+2212 minus only for negatives', () {
      expect(signedHk(-8420), '−HK\$8,420');
      expect(signedHk(100), r'HK$100');
    });

    test('parseAmount mirrors parseFloat(x || 0)', () {
      expect(parseAmount('12.5'), 12.5);
      expect(parseAmount(''), 0);
      expect(parseAmount(null), 0);
      expect(parseAmount('  3 '), 3);
      expect(parseAmount('abc'), 0);
    });
  });
}
