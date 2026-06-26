import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/ledger_notifier.dart';
import '../theme/tokens.dart';
import '../widgets/enter_animations.dart';
import '../widgets/primary_button.dart';
import '../widgets/selectable_chip.dart';
import 'sheet_chrome.dart';

const _types = ['Cash', 'Debit', 'Credit', 'Savings', 'Investment', 'Loan'];
const _currencies = ['HKD', 'USD', 'GBP', 'EUR', 'JPY'];
// Banks we bundle a logo for — picking one fills the name + shows the logo.
const _banks = ['HSBC', 'Standard Chartered', 'Wise', 'Interactive Brokers'];

/// Bottom sheet to add a new account or edit an existing one (balance plus, for
/// credit cards, the statement-cycle settings). Mounted by the shell while open.
class AddAccountSheet extends ConsumerStatefulWidget {
  const AddAccountSheet({super.key});

  @override
  ConsumerState<AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends ConsumerState<AddAccountSheet> {
  late final TextEditingController _name;
  late final TextEditingController _balance;
  late final TextEditingController _limit;
  late final TextEditingController _stmtDay;
  late final TextEditingController _dueDay;
  late final TextEditingController _stmtBal;

  @override
  void initState() {
    super.initState();
    final s = ref.read(ledgerProvider);
    _name = TextEditingController(text: s.newName);
    _balance = TextEditingController(text: s.newBalance);
    _limit = TextEditingController(text: s.newLimit);
    _stmtDay = TextEditingController(text: s.newStatementDay);
    _dueDay = TextEditingController(text: s.newDueDay);
    _stmtBal = TextEditingController(text: s.newStatementBalance);
  }

  @override
  void dispose() {
    for (final c in [_name, _balance, _limit, _stmtDay, _dueDay, _stmtBal]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(ledgerProvider);
    final n = ref.read(ledgerProvider.notifier);

    final editing = s.editingAccountId.isNotEmpty;
    final edited = editing ? s.accountById(s.editingAccountId) : null;
    final isLiability = editing
        ? (edited?.isLiability ?? false)
        : (s.newType == 'Credit' || s.newType == 'Loan');
    final showCredit = editing
        ? (edited?.isCreditCard ?? false)
        : (s.newType == 'Credit' || s.newType == 'Loan');

    return Stack(
      children: [
        Positioned.fill(
          child: EnterFade(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: n.closeAcctSheet,
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: EnterSlideUp(
            child: SheetPanel(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.92,
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SheetHandle(),
                      SheetHeader(
                        title: editing ? 'Edit account' : 'Add account',
                        onCancel: n.closeAcctSheet,
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fieldLabel('Account name'),
                              const SizedBox(height: 7),
                              _input(
                                controller: _name,
                                onChanged: n.setNewName,
                                hint: 'e.g. DBS Savings',
                                borderColor: s.newInvalid
                                    ? AppColors.expense
                                    : AppColors.hairline,
                              ),
                              if (!editing) ...[
                                const SizedBox(height: 16),
                                _fieldLabel('Bank (optional)'),
                                const SizedBox(height: 7),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final b in _banks)
                                      SelectableChip(
                                        label: b,
                                        selected: s.newName.trim() == b,
                                        onTap: () {
                                          _name.text = b;
                                          _name.selection =
                                              TextSelection.collapsed(
                                                offset: b.length,
                                              );
                                          n.setNewName(b);
                                        },
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 17),
                                _fieldLabel('Type'),
                                const SizedBox(height: 7),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final t in _types)
                                      SelectableChip(
                                        label: t,
                                        selected: s.newType == t,
                                        onTap: () => n.setNewType(t),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 17),
                                _fieldLabel('Currency'),
                                const SizedBox(height: 7),
                                Row(
                                  children: [
                                    for (
                                      var i = 0;
                                      i < _currencies.length;
                                      i++
                                    ) ...[
                                      if (i > 0) const SizedBox(width: 8),
                                      Expanded(
                                        child: SelectableChip(
                                          label: _currencies[i],
                                          selected:
                                              s.newCurrency == _currencies[i],
                                          onTap: () =>
                                              n.setNewCurrency(_currencies[i]),
                                          radius: 11,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                              const SizedBox(height: 17),
                              _fieldLabel(
                                isLiability
                                    ? 'Amount owed'
                                    : (editing ? 'Balance' : 'Opening balance'),
                              ),
                              const SizedBox(height: 7),
                              _input(
                                controller: _balance,
                                onChanged: n.setNewBalance,
                                hint: '0',
                                borderColor: AppColors.hairline,
                                mono: true,
                                number: true,
                              ),
                              if (showCredit) ...[
                                const SizedBox(height: 22),
                                Text(
                                  'STATEMENT CYCLE',
                                  style: AppText.eyebrow().copyWith(
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _fieldLabel('Credit limit'),
                                const SizedBox(height: 7),
                                _input(
                                  controller: _limit,
                                  onChanged: n.setNewLimit,
                                  hint: 'e.g. 80000',
                                  borderColor: AppColors.hairline,
                                  mono: true,
                                  number: true,
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _dayField(
                                        'Closes on (day)',
                                        _stmtDay,
                                        n.setNewStatementDay,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _dayField(
                                        'Due on (day)',
                                        _dueDay,
                                        n.setNewDueDay,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _fieldLabel('Statement balance (owed now)'),
                                const SizedBox(height: 7),
                                _input(
                                  controller: _stmtBal,
                                  onChanged: n.setNewStatementBalance,
                                  hint: 'from your latest statement',
                                  borderColor: AppColors.hairline,
                                  mono: true,
                                  number: true,
                                ),
                              ],
                              const SizedBox(height: 22),
                              PrimaryButton(
                                label: editing ? 'Save changes' : 'Add account',
                                onTap: n.saveAccount,
                              ),
                              if (editing) ...[
                                const SizedBox(height: 12),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _confirmDelete(
                                    n,
                                    s.editingAccountId,
                                    edited?.name ?? 'this account',
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: AppColors.expense.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'Delete account',
                                      style: AppText.ui(
                                        15,
                                        FontWeight.w600,
                                        color: AppColors.expense,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(LedgerNotifier n, String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.sheet,
        title: Text('Delete $name?', style: AppText.ui(16, FontWeight.w700)),
        content: Text(
          "This removes the account and its transactions. This can't be undone.",
          style: AppText.ui(
            13,
            FontWeight.w400,
            color: AppColors.muted,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppText.ui(14, FontWeight.w600, color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: AppText.ui(14, FontWeight.w700, color: AppColors.expense),
            ),
          ),
        ],
      ),
    );
    if (ok == true) n.deleteAccount(id);
  }

  Widget _fieldLabel(String text) => Text(
    text,
    style: AppText.ui(12, FontWeight.w600, color: AppColors.muted),
  );

  Widget _dayField(
    String label,
    TextEditingController controller,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 7),
        _input(
          controller: controller,
          onChanged: onChanged,
          hint: '1–31',
          borderColor: AppColors.hairline,
          mono: true,
          number: true,
        ),
      ],
    );
  }

  Widget _input({
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    required String hint,
    required Color borderColor,
    bool mono = false,
    bool number = false,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      cursorColor: AppColors.brand,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: mono
          ? AppText.mono(15, FontWeight.w500)
          : AppText.ui(15, FontWeight.w500),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.card,
        hintText: hint,
        hintStyle: AppText.ui(15, FontWeight.w400, color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 13,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: const BorderSide(color: AppColors.brand),
        ),
      ),
    );
  }
}
