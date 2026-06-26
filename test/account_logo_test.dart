import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/view/account_logo.dart';

void main() {
  group('account logo registry', () {
    test('exposes HSBC and Standard Chartered as selectable logos', () {
      expect(kAccountLogos.containsKey('hsbc'), isTrue);
      expect(kAccountLogos.containsKey('standard_chartered'), isTrue);
    });

    test('every registered logo has a label and a bundled asset path', () {
      for (final entry in kAccountLogos.entries) {
        expect(entry.value.label, isNotEmpty);
        expect(entry.value.asset, startsWith('assets/logos/'));
        expect(entry.value.asset, endsWith('.png'));
      }
    });

    test('logoAssetForKey resolves a known key and returns null otherwise', () {
      expect(logoAssetForKey('hsbc'), 'assets/logos/hsbc.png');
      expect(logoAssetForKey('standard_chartered'),
          'assets/logos/standard_chartered.png');
      expect(logoAssetForKey('not_a_bank'), isNull);
    });
  });
}
