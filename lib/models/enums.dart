/// Domain enums shared across models and state. Pure Dart.
library;

/// Whether a transaction adds, removes, or moves money.
enum TxnType { expense, income, transfer }

/// Whether an account counts toward assets or liabilities in net worth.
enum AccountNature { asset, liability }

/// The repeat cadence chosen in the Add Transaction sheet.
enum RepeatMode { off, weekly, monthly, installment }

/// Whether a recurring entry is a subscription or an installment plan.
enum RecurringKind { sub, installment }

/// Looks an enum value up by [Enum.name], falling back when absent — used by
/// the `fromMap` deserialisers so a bad/old DB value can't crash a load.
T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((v) => v.name == name, orElse: () => fallback);
