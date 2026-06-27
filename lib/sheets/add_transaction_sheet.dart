import 'dart:math';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/money.dart';
import '../core/statement.dart';
import '../models/enums.dart';
import '../state/ledger_notifier.dart';
import '../state/ledger_state.dart';
import '../theme/category_icons.dart';
import '../theme/hex_color.dart';
import '../theme/tokens.dart';
import '../widgets/account_avatar.dart';
import '../widgets/enter_animations.dart';
import '../widgets/keypad.dart';
import '../widgets/month_calendar.dart';
import '../widgets/primary_button.dart';
import '../widgets/segmented_control.dart';
import 'sheet_chrome.dart';

/// The full Add Transaction flow: type, keypad-driven amount, meta rows and the
/// account / category / repeat pickers. Mounted by the shell while open.
class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key});

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  late final TextEditingController _payee;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _payee = TextEditingController(text: ref.read(ledgerProvider).payee);
    _note = TextEditingController(text: ref.read(ledgerProvider).note);
  }

  @override
  void dispose() {
    _payee.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(ledgerProvider);
    final n = ref.read(ledgerProvider.notifier);

    // Keep the payee field in sync when the draft resets after a save.
    ref.listen<String>(ledgerProvider.select((v) => v.payee), (_, next) {
      if (next.isEmpty && _payee.text.isNotEmpty) _payee.clear();
    });
    ref.listen<String>(ledgerProvider.select((v) => v.note), (_, next) {
      if (next.isEmpty && _note.text.isNotEmpty) _note.clear();
    });

    // The design spec's full Add Transaction sheet is 768px tall; capping lower
    // forced the amount/fields area to scroll above the keypad. Fill the height
    // available (within the phone frame) up to that, so all fields fit at once.
    final panelHeight = min(768.0, MediaQuery.of(context).size.height - 24);

    return Stack(
      children: [
        Positioned.fill(
          child: EnterFade(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: n.closeSheet,
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: EnterSlideUp(
            child: SheetPanel(
              height: panelHeight,
              child: Stack(
                children: [
                  _content(s, n),
                  if (s.picker != ActivePicker.none) _pickerLayer(s, n),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _content(LedgerState s, LedgerNotifier n) {
    final sign = switch (s.txnType) {
      TxnType.expense => '−',
      TxnType.income => '+',
      TxnType.transfer => '⇄ ',
    };
    final amountText = s.amount.isEmpty
        ? '${sign}HK\$0'
        : '${sign}HK\$${s.amount}';
    final amountColor = s.amount.isEmpty
        ? AppColors.idleTab
        : (s.txnType == TxnType.income ? AppColors.brand : AppColors.text);
    final cat = s.categoryById(s.categoryId);
    final editing = s.editingTxnId != 0;

    return Column(
      children: [
        const SheetHandle(),
        SheetHeader(
          title: editing ? 'Edit transaction' : 'New transaction',
          onCancel: n.closeSheet,
          bottomPadding: 8,
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: SegmentedControl(
                    labels: const ['Expense', 'Income', 'Transfer'],
                    activeIndex: s.txnType.index,
                    background: AppColors.deep,
                    onChanged: (i) => n.setTxnType(TxnType.values[i]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
                  child: Column(
                    children: [
                      Text(
                        amountText,
                        style: AppText.keypadAmount.copyWith(
                          color: amountColor,
                        ),
                      ),
                      if (s.invalid)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Enter an amount first',
                            style: AppText.ui(
                              12,
                              FontWeight.w600,
                              color: AppColors.expense,
                            ),
                          ),
                        ),
                      if (s.repeat != RepeatMode.off)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _repeatSummary(s),
                            style: AppText.ui(
                              12,
                              FontWeight.w600,
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        border: Border.all(color: AppColors.hairline),
                        borderRadius: BorderRadius.circular(AppRadii.card),
                      ),
                      child: Column(
                        children: [
                          _metaRow(
                            label: s.isTransfer ? 'From' : 'Account',
                            trailing: _valueChevron(
                              s.accountById(s.accountId)?.name ?? '',
                            ),
                            onTap: n.openAccountPicker,
                          ),
                          if (s.isTransfer)
                            _metaRow(
                              label: 'To',
                              trailing: _valueChevron(
                                s.accountById(s.toAccountId)?.name ?? '',
                              ),
                              onTap: n.openToPicker,
                            ),
                          _metaRow(
                            label: 'Category',
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: hexColor('${cat.color}29'),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Icon(
                                    symbolFor(cat.icon),
                                    size: 15,
                                    color: hexColor(cat.color),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${cat.name} ›',
                                  style: AppText.ui(14, FontWeight.w600),
                                ),
                              ],
                            ),
                            onTap: n.openCategoryPicker,
                          ),
                          _metaRow(
                            label: 'Payee',
                            compact: true,
                            trailing: TextField(
                              controller: _payee,
                              onChanged: n.setPayee,
                              textAlign: TextAlign.right,
                              cursorColor: AppColors.brand,
                              style: AppText.ui(14, FontWeight.w600),
                              decoration: InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                hintText: 'who / what',
                                hintStyle: AppText.ui(
                                  14,
                                  FontWeight.w600,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ),
                          _metaRow(
                            label: 'Note',
                            compact: true,
                            trailing: TextField(
                              controller: _note,
                              onChanged: n.setNote,
                              textAlign: TextAlign.right,
                              cursorColor: AppColors.brand,
                              style: AppText.ui(14, FontWeight.w600),
                              decoration: InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                hintText: 'optional',
                                hintStyle: AppText.ui(
                                  14,
                                  FontWeight.w600,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ),
                          _metaRow(
                            label: s.repeat == RepeatMode.monthly
                                ? 'Starts'
                                : 'Date',
                            trailing: Text(
                              '${compactDate(s.txnDate)} ›',
                              style: AppText.ui(14, FontWeight.w600),
                            ),
                            onTap: n.openDatePicker,
                            last: editing,
                          ),
                          if (!editing)
                            _metaRow(
                              label: 'Repeat',
                              trailing: Text(
                                '${_repeatLabel(s)} ›',
                                style: AppText.ui(
                                  14,
                                  FontWeight.w600,
                                  color: s.repeat == RepeatMode.off
                                      ? AppColors.text
                                      : AppColors.brand,
                                ),
                              ),
                              onTap: n.openRepeatPicker,
                              last: s.repeat != RepeatMode.monthly,
                            ),
                          if (!editing && s.repeat == RepeatMode.monthly)
                            _metaRow(
                              label: 'Ends',
                              trailing: Text(
                                '${s.recurEnd == null ? 'Ongoing' : compactDate(s.recurEnd!)} ›',
                                style: AppText.ui(
                                  14,
                                  FontWeight.w600,
                                  color: s.recurEnd == null
                                      ? AppColors.muted
                                      : AppColors.text,
                                ),
                              ),
                              onTap: n.openRecurEndPicker,
                              last: true,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
          child: Keypad(onKey: n.press),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: editing ? 'Save changes' : 'Save',
                  onTap: () => n.save(close: true),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: editing
                      ? () => n.deleteTxn(s.editingTxnId)
                      : () => n.save(close: false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: editing
                          ? AppColors.expense.withValues(alpha: 0.14)
                          : AppColors.keypad,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: editing
                            ? AppColors.expense.withValues(alpha: 0.4)
                            : AppColors.hairlineStrong,
                      ),
                    ),
                    child: Text(
                      editing ? 'Delete' : '+ another',
                      style: AppText.ui(
                        14,
                        FontWeight.w600,
                        color: editing ? AppColors.expense : AppColors.text,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _repeatLabel(LedgerState s) => switch (s.repeat) {
    RepeatMode.off => 'One-time',
    RepeatMode.weekly => 'Weekly',
    RepeatMode.monthly => 'Monthly',
    RepeatMode.installment => '${s.installMonths}× months',
  };

  String _repeatSummary(LedgerState s) {
    final amt = parseAmount(s.amount);
    return switch (s.repeat) {
      RepeatMode.off => '',
      RepeatMode.weekly => 'Repeats every week',
      RepeatMode.monthly => 'Repeats every month',
      RepeatMode.installment =>
        amt > 0
            ? '${s.installMonths} payments of ${hk(s.installPerMonth)}'
            : '${s.installMonths} installments',
    };
  }

  Widget _valueChevron(String value) => Text(
    '$value ›',
    style: AppText.ui(14, FontWeight.w600),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );

  Widget _metaRow({
    required String label,
    required Widget trailing,
    VoidCallback? onTap,
    bool last = false,
    bool compact = false,
  }) {
    final row = Container(
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: compact ? 9 : 11),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: AppColors.hairlineSoft)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: AppText.ui(14, FontWeight.w400, color: AppColors.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }

  // ---- Picker layer ----------------------------------------------------------

  Widget _pickerLayer(LedgerState s, LedgerNotifier n) {
    return Positioned.fill(
      child: EnterSlideUp(
        duration: AppDurations.picker,
        child: Container(
          color: AppColors.sheet,
          child: switch (s.picker) {
            ActivePicker.account => _accountPicker(s, n),
            ActivePicker.category => _categoryPicker(s, n),
            ActivePicker.repeat => _repeatPicker(s, n),
            ActivePicker.date => _datePicker(s, n),
            ActivePicker.recurEnd => _recurEndPicker(s, n),
            ActivePicker.none => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }

  Widget _pickerHeader(
    String title,
    VoidCallback onBack, {
    VoidCallback? onDone,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBack,
            child: Text(
              '‹ Back',
              style: AppText.ui(15, FontWeight.w400, color: AppColors.muted),
            ),
          ),
          Text(title, style: AppText.ui(16, FontWeight.w700)),
          onDone == null
              ? const SizedBox(width: 44)
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDone,
                  child: Text(
                    'Done',
                    style: AppText.ui(
                      15,
                      FontWeight.w600,
                      color: AppColors.brand,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _accountPicker(LedgerState s, LedgerNotifier n) {
    final selectedId = s.picking == PickingSide.to
        ? s.toAccountId
        : s.accountId;
    return Column(
      children: [
        _pickerHeader(
          s.picking == PickingSide.to ? 'Transfer to' : 'Account',
          n.closePicker,
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            itemCount: s.accounts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 9),
            itemBuilder: (_, i) {
              final a = s.accounts[i];
              final selected = a.id == selectedId;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => n.pickAccount(a.id),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(
                      color: selected ? AppColors.brand : AppColors.hairline,
                    ),
                  ),
                  child: Row(
                    children: [
                      AccountAvatar(account: a),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              a.name,
                              style: AppText.ui(15, FontWeight.w600),
                            ),
                            Text(a.sub, style: AppText.muted12),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        signedMoney(a.balance, a.currency),
                        style: AppText.mono(
                          14,
                          FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Symbols.check_rounded,
                        size: 18,
                        color: selected ? AppColors.brand : Colors.transparent,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _categoryPicker(LedgerState s, LedgerNotifier n) {
    return Column(
      children: [
        _pickerHeader('Category', n.closePicker),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Tap to choose · long-press to edit',
              style: AppText.ui(11, FontWeight.w500, color: AppColors.muted),
            ),
          ),
        ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 11,
            crossAxisSpacing: 11,
            childAspectRatio: 0.92,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              for (final c in s.categories)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => n.pickCategory(c.id),
                  onLongPress: () => n.openEditCategory(c.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      border: Border.all(
                        color: c.id == s.categoryId
                            ? AppColors.brand
                            : AppColors.hairline,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: hexColor('${c.color}29'),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            symbolFor(c.icon),
                            size: 23,
                            color: hexColor(c.color),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          c.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.ui(12, FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: n.openNewCategory,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Symbols.add_rounded,
                          size: 23,
                          color: AppColors.brand,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'New',
                        textAlign: TextAlign.center,
                        style: AppText.ui(
                          12,
                          FontWeight.w600,
                          color: AppColors.brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _datePicker(LedgerState s, LedgerNotifier n) {
    return Column(
      children: [
        _pickerHeader('Date', n.closePicker),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: MonthCalendar(
              selected: s.txnDate,
              onPick: n.pickDate,
            ),
          ),
        ),
      ],
    );
  }

  /// End-date picker for a monthly repeat: a calendar plus an "Ongoing" choice
  /// that clears the end date.
  Widget _recurEndPicker(LedgerState s, LedgerNotifier n) {
    return Column(
      children: [
        _pickerHeader('Ends', n.closePicker),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => n.setRecurEnd(null),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.recurEnd == null
                    ? AppColors.brand.withValues(alpha: 0.16)
                    : AppColors.card,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: s.recurEnd == null
                      ? AppColors.brand
                      : AppColors.hairline,
                ),
              ),
              child: Text(
                'Ongoing (no end date)',
                style: AppText.ui(
                  14,
                  FontWeight.w600,
                  color: s.recurEnd == null ? AppColors.brand : AppColors.text,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: MonthCalendar(
              selected: s.recurEnd ?? s.txnDate,
              onPick: n.setRecurEnd,
            ),
          ),
        ),
      ],
    );
  }

  Widget _repeatPicker(LedgerState s, LedgerNotifier n) {
    final amt = parseAmount(s.amount);
    return Column(
      children: [
        _pickerHeader('Repeat', n.closePicker, onDone: n.closePicker),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              _repeatOption(
                'One-time',
                s.repeat == RepeatMode.off,
                n.setRepeat,
                RepeatMode.off,
              ),
              const SizedBox(height: 10),
              _repeatOption(
                'Repeat weekly',
                s.repeat == RepeatMode.weekly,
                n.setRepeat,
                RepeatMode.weekly,
              ),
              const SizedBox(height: 10),
              _repeatOption(
                'Repeat monthly',
                s.repeat == RepeatMode.monthly,
                n.setRepeat,
                RepeatMode.monthly,
              ),
              const SizedBox(height: 10),
              _installmentOption(s, n, amt),
            ],
          ),
        ),
      ],
    );
  }

  Widget _repeatOption(
    String label,
    bool selected,
    void Function(RepeatMode) set,
    RepeatMode mode,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => set(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.hairline,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppText.ui(15, FontWeight.w600)),
            Icon(
              Symbols.check_rounded,
              size: 18,
              color: selected ? AppColors.brand : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _installmentOption(LedgerState s, LedgerNotifier n, double amt) {
    final selected = s.repeat == RepeatMode.installment;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => n.setRepeat(RepeatMode.installment),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.hairline,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Installments',
                      style: AppText.ui(15, FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Split a liability over N months',
                      style: AppText.muted12,
                    ),
                  ],
                ),
                Icon(
                  Symbols.check_rounded,
                  size: 18,
                  color: selected ? AppColors.brand : Colors.transparent,
                ),
              ],
            ),
            if (selected) ...[
              const SizedBox(height: 16),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Months',
                    style: AppText.ui(
                      14,
                      FontWeight.w400,
                      color: AppColors.muted,
                    ),
                  ),
                  Row(
                    children: [
                      _stepperButton(Symbols.remove_rounded, n.decMonths),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          '${s.installMonths}',
                          style: AppText.mono(20, FontWeight.w600),
                        ),
                      ),
                      _stepperButton(Symbols.add_rounded, n.incMonths),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: AppColors.deep,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      amt > 0
                          ? '${hk(s.installPerMonth)} / month'
                          : 'Enter an amount',
                      style: AppText.mono(
                        18,
                        FontWeight.w600,
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      amt > 0
                          ? 'Total ${hk(amt)} over ${s.installMonths} months'
                          : 'Split across ${s.installMonths} months',
                      style: AppText.muted12,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.keypad,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: AppColors.text),
      ),
    );
  }
}
