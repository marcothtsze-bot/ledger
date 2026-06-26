import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/models/category.dart';
import 'package:ledger/state/ledger_state.dart';

void main() {
  group('Category model', () {
    test('round-trips through toMap/fromMap', () {
      const c = Category(
        id: 'coffee',
        name: 'Coffee',
        color: '#d8a25e',
        icon: 'local_cafe',
      );
      final back = Category.fromMap(c.toMap());
      expect(back.id, 'coffee');
      expect(back.name, 'Coffee');
      expect(back.color, '#d8a25e');
      expect(back.icon, 'local_cafe');
    });

    test('copyWith replaces only the given fields', () {
      const c = Category(id: 'x', name: 'X', color: '#fff', icon: 'home');
      final e = c.copyWith(name: 'Y', icon: 'savings');
      expect(e.id, 'x');
      expect(e.name, 'Y');
      expect(e.icon, 'savings');
      expect(e.color, '#fff');
    });
  });

  group('category CRUD on LedgerState', () {
    final base = LedgerState.initial();

    test('addCategory appends a findable category', () {
      final next = base.addCategory(
        name: 'Childcare',
        icon: 'child_care',
        color: '#fcd34d',
      );
      expect(next.categories.length, base.categories.length + 1);
      final added = next.categories.last;
      expect(added.name, 'Childcare');
      expect(next.categoryById(added.id).icon, 'child_care');
    });

    test('addCategory gives same-named categories distinct ids', () {
      final a = base.addCategory(name: 'Travel', icon: 'flight', color: '#2dd4bf');
      final b = a.addCategory(name: 'Travel', icon: 'flight', color: '#2dd4bf');
      final ids = b.categories.map((c) => c.id).toList();
      expect(ids.length, ids.toSet().length, reason: 'ids must be unique');
    });

    test('editCategory updates fields in place by id', () {
      final next = base.editCategory('dining', name: 'Eating out', icon: 'liquor');
      final c = next.categoryById('dining');
      expect(c.name, 'Eating out');
      expect(c.icon, 'liquor');
      expect(c.color, '#ff7a6b'); // unchanged
    });

    test('deleteCategory removes it and reassigns its transactions', () {
      // Seed txn #1 is catId 'dining'; the draft category is also 'dining'.
      final next = base.deleteCategory('dining');
      expect(next.categories.any((c) => c.id == 'dining'), isFalse);
      final fallback = next.categories.first.id;
      expect(next.transactions.firstWhere((t) => t.id == 1).catId, fallback);
      expect(next.categoryId, fallback); // draft selection moved off the deleted one
    });

    test('deleteCategory refuses to remove the last remaining category', () {
      var s = base;
      final ids = s.categories.map((c) => c.id).toList();
      for (final id in ids.take(ids.length - 1)) {
        s = s.deleteCategory(id);
      }
      expect(s.categories.length, 1);
      final lastId = s.categories.first.id;
      final after = s.deleteCategory(lastId);
      expect(after.categories.length, 1, reason: 'last category is protected');
      expect(after.categories.first.id, lastId);
    });

    test('deleteCategory reassigns recurring rules off the deleted category', () {
      expect(base.recurring.any((r) => r.catId == 'subs'), isTrue);
      final next = base.deleteCategory('subs');
      expect(next.recurring.any((r) => r.catId == 'subs'), isFalse);
      for (final r in next.recurring) {
        expect(
          next.categories.any((c) => c.id == r.catId),
          isTrue,
          reason: 'every recurring rule must point at a live category',
        );
      }
    });

    test('fromSnapshot normalizes a stale draft categoryId to a live one', () {
      final snap = base.deleteCategory('dining').toSnapshot();
      final restored = LedgerState.fromSnapshot(snap);
      expect(restored.categories.any((c) => c.id == 'dining'), isFalse);
      expect(
        restored.categories.any((c) => c.id == restored.categoryId),
        isTrue,
        reason: 'draft category must reference a live category',
      );
    });

    test('payStatement uses a live category after Payment is deleted', () {
      final s = base.deleteCategory('payment').copyWith(payCardId: 'citi');
      final paid = s.payStatement('hsbc');
      final payTxn = paid.transactions.first;
      expect(
        paid.categories.any((c) => c.id == payTxn.catId),
        isTrue,
        reason: 'statement-payment txn must reference a live category',
      );
    });
  });
}
