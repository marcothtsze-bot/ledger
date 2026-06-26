import '../models/account.dart';

/// A short, human-readable type label for an account — shown as a badge so the
/// kind of account (Debit, Credit, Investment, …) is clear at a glance.
String accountTypeLabel(Account a) {
  if (a.isCreditCard) return 'Credit';
  if (a.group == 'invest') return 'Investment';
  final first = a.sub.split('·').first.trim();
  const known = {'Debit', 'Credit', 'Cash', 'Savings', 'Loan', 'Investment'};
  if (known.contains(first)) return first;
  final lower = a.sub.toLowerCase();
  if (lower.contains('multi-currency')) return 'Multi-currency';
  if (lower.contains('manual asset')) return 'Asset';
  return a.isLiability ? 'Liability' : 'Account';
}
