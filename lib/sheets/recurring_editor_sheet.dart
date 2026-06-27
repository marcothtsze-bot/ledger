import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/money.dart';
import '../core/statement.dart';
import '../models/enums.dart';
import '../state/ledger_notifier.dart';
import '../theme/hex_color.dart';
import '../theme/icon_catalog.dart';
import '../theme/tokens.dart';
import '../widgets/confirm_overlay.dart';
import '../widgets/enter_animations.dart';
import '../widgets/icon_tile.dart';
import '../widgets/month_calendar.dart';
import '../widgets/primary_button.dart';
import '../widgets/selectable_chip.dart';
import 'sheet_chrome.dart';

/// Bottom sheet to edit or cancel a subscription/recurring payment: name,
/// amount, icon, colour, pay-from account and next-due date. Mounted while
/// `recurringEditorId` is set.
class RecurringEditorSheet extends ConsumerStatefulWidget {
  const RecurringEditorSheet({super.key});

  @override
  ConsumerState<RecurringEditorSheet> createState() =>
      _RecurringEditorSheetState();
}

class _RecurringEditorSheetState extends ConsumerState<RecurringEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late String _icon;
  late String _color;
  late String _accountId;
  late DateTime _nextDate;
  late final bool _isInstallment;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showCalendar = false;
  bool _showEndCalendar = false;
  bool _invalid = false;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(ledgerProvider);
    final matches = s.recurring.where((r) => r.id == s.recurringEditorId);
    final r = matches.isEmpty ? null : matches.first;
    final cat = r == null ? null : s.categoryById(r.catId);
    _isInstallment = r?.kind == RecurringKind.installment;
    _name = TextEditingController(text: r?.name ?? '');
    _amount = TextEditingController(text: r == null ? '' : _fmt(r.amount));
    _icon = r?.icon ?? cat?.icon ?? kSubscriptionIcons.first;
    _color = r?.color ?? cat?.color ?? kCategoryColors[7];
    _accountId = r?.accountId ??
        (s.accounts.isNotEmpty ? s.accounts.first.id : '');
    _nextDate = r?.nextDate ?? DateTime.now();
    _startDate = r?.startDate;
    _endDate = r?.endDate;
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(ledgerProvider);
    final n = ref.read(ledgerProvider.notifier);
    final c = hexColor(_color);

    return Stack(
      children: [
        Positioned.fill(
          child: EnterFade(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: n.closeRecurringEditor,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SheetHandle(),
                    SheetHeader(
                      title: _isInstallment
                          ? 'Edit installment'
                          : 'Edit subscription',
                      onCancel: n.closeRecurringEditor,
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: IconTile(
                                size: 60,
                                radius: 18,
                                bg: c.withValues(alpha: 0.16),
                                fg: c,
                                glyphSize: 30,
                                icon: iconFor(_icon),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _label('Name'),
                            const SizedBox(height: 7),
                            _field(_name, hint: 'e.g. Netflix', invalid: _invalid,
                                onChanged: (_) => setState(() => _invalid = false)),
                            const SizedBox(height: 16),
                            _label(_isInstallment ? 'Monthly amount' : 'Amount'),
                            const SizedBox(height: 7),
                            _field(_amount, hint: '0', mono: true, number: true),
                            const SizedBox(height: 16),
                            _label('Icon'),
                            const SizedBox(height: 9),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final ic in kSubscriptionIcons)
                                  _iconTile(ic, c),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _label('Colour'),
                            const SizedBox(height: 9),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final hex in kCategoryColors)
                                  _swatch(hex),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _label('Pay from'),
                            const SizedBox(height: 7),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final a in s.accounts)
                                  SelectableChip(
                                    label: a.name,
                                    selected: _accountId == a.id,
                                    onTap: () =>
                                        setState(() => _accountId = a.id),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _label('Next due'),
                            const SizedBox(height: 7),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(
                                  () => _showCalendar = !_showCalendar),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 15, vertical: 13),
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.field),
                                  border: Border.all(color: AppColors.hairline),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(compactDate(_nextDate),
                                        style: AppText.mono(15, FontWeight.w500)),
                                    Text(_showCalendar ? 'Done' : 'Change',
                                        style: AppText.ui(13, FontWeight.w600,
                                            color: AppColors.brand)),
                                  ],
                                ),
                              ),
                            ),
                            if (_showCalendar) ...[
                              const SizedBox(height: 12),
                              MonthCalendar(
                                selected: _nextDate,
                                onPick: (d) => setState(() {
                                  _nextDate = d;
                                  _showCalendar = false;
                                }),
                              ),
                            ],
                            if (!_isInstallment) ...[
                              const SizedBox(height: 16),
                              _label('Ends'),
                              const SizedBox(height: 7),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(
                                    () => _showEndCalendar = !_showEndCalendar),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 15, vertical: 13),
                                  decoration: BoxDecoration(
                                    color: AppColors.card,
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.field),
                                    border:
                                        Border.all(color: AppColors.hairline),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _endDate == null
                                            ? 'Ongoing'
                                            : compactDate(_endDate!),
                                        style: AppText.mono(15, FontWeight.w500),
                                      ),
                                      Text(
                                        _showEndCalendar ? 'Done' : 'Change',
                                        style: AppText.ui(13, FontWeight.w600,
                                            color: AppColors.brand),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_showEndCalendar) ...[
                                const SizedBox(height: 10),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => setState(() {
                                    _endDate = null;
                                    _showEndCalendar = false;
                                  }),
                                  child: Text(
                                    'Set to ongoing (no end date)',
                                    style: AppText.ui(13, FontWeight.w600,
                                        color: AppColors.muted),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                MonthCalendar(
                                  selected: _endDate ?? _nextDate,
                                  onPick: (d) => setState(() {
                                    _endDate = d;
                                    _showEndCalendar = false;
                                  }),
                                ),
                              ],
                              if (_startDate != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Started ${compactDate(_startDate!)}',
                                  style: AppText.muted12,
                                ),
                              ],
                            ],
                            const SizedBox(height: 22),
                            PrimaryButton(
                              label: 'Save changes',
                              onTap: () => _save(n),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _confirming = true),
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                      color: AppColors.expense
                                          .withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                    _isInstallment
                                        ? 'Cancel plan'
                                        : 'Cancel subscription',
                                    style: AppText.ui(15, FontWeight.w600,
                                        color: AppColors.expense)),
                              ),
                            ),
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
        if (_confirming)
          ConfirmOverlay(
            title: 'Cancel ${_name.text.trim()}?',
            message: _isInstallment
                ? 'This removes the installment plan from your upcoming '
                      'payments. Payments already made are kept.'
                : 'This removes it from your subscriptions and upcoming payments.',
            confirmLabel: _isInstallment ? 'Cancel plan' : 'Cancel it',
            cancelLabel: 'Keep',
            onCancel: () => setState(() => _confirming = false),
            onConfirm: () => n.deleteRecurringById(
              ref.read(ledgerProvider).recurringEditorId,
            ),
          ),
      ],
    );
  }

  void _save(LedgerNotifier n) {
    if (_name.text.trim().isEmpty) {
      setState(() => _invalid = true);
      return;
    }
    n.saveRecurring(
      ref.read(ledgerProvider).recurringEditorId,
      name: _name.text.trim(),
      amount: parseAmount(_amount.text),
      icon: _icon,
      color: _color,
      accountId: _accountId,
      nextDate: _nextDate,
      endDate: _endDate,
    );
  }

  Widget _label(String t) =>
      Text(t, style: AppText.ui(12, FontWeight.w600, color: AppColors.muted));

  Widget _field(TextEditingController c,
      {required String hint,
      bool mono = false,
      bool number = false,
      bool invalid = false,
      ValueChanged<String>? onChanged}) {
    return TextField(
      controller: c,
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: BorderSide(
              color: invalid ? AppColors.expense : AppColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: const BorderSide(color: AppColors.brand),
        ),
      ),
    );
  }

  Widget _iconTile(String ligature, Color c) {
    final selected = _icon == ligature;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _icon = ligature),
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.16) : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.tileMed),
          border: Border.all(
              color: selected ? c : AppColors.hairline,
              width: selected ? 1.5 : 1),
        ),
        child: Icon(iconFor(ligature),
            size: 22, color: selected ? c : AppColors.text),
      ),
    );
  }

  Widget _swatch(String hex) {
    final selected = _color == hex;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _color = hex),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hexColor(hex),
          shape: BoxShape.circle,
          border: Border.all(
              color: selected ? Colors.white : Colors.transparent, width: 2),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 18, color: Colors.black)
            : null,
      ),
    );
  }
}
