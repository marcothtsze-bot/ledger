import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/money.dart';
import '../state/ledger_notifier.dart';
import '../theme/hex_color.dart';
import '../theme/icon_catalog.dart';
import '../theme/tokens.dart';
import '../widgets/confirm_overlay.dart';
import '../widgets/enter_animations.dart';
import '../widgets/primary_button.dart';
import 'sheet_chrome.dart';

/// Bottom sheet to add a new category or edit/delete an existing one
/// (name + icon + colour). Mounted by the shell while `catEditorId` is set.
class CategoryEditorSheet extends ConsumerStatefulWidget {
  const CategoryEditorSheet({super.key});

  @override
  ConsumerState<CategoryEditorSheet> createState() =>
      _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends ConsumerState<CategoryEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _budget;
  late String _icon;
  late String _color;
  bool _invalid = false;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(ledgerProvider);
    final existing = s.catEditorId == 'new'
        ? null
        : s.categoryById(s.catEditorId);
    final budget = existing == null ? null : s.budgets[s.catEditorId];
    _name = TextEditingController(text: existing?.name ?? '');
    _budget = TextEditingController(
      text: budget == null ? '' : _fmtAmount(budget),
    );
    _icon = existing?.icon ?? kCategoryIcons.first;
    _color = existing?.color ?? kCategoryColors[7]; // brand green default
  }

  static String _fmtAmount(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(ledgerProvider);
    final n = ref.read(ledgerProvider.notifier);
    final editing = s.catEditorId != 'new' && s.catEditorId.isNotEmpty;
    final c = hexColor(_color);

    return Stack(
      children: [
        Positioned.fill(
          child: EnterFade(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: n.closeCategoryEditor,
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
                      title: editing ? 'Edit category' : 'New category',
                      onCancel: n.closeCategoryEditor,
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _preview(c),
                            const SizedBox(height: 18),
                            _label('Name'),
                            const SizedBox(height: 7),
                            _nameField(c),
                            const SizedBox(height: 18),
                            _label('Icon'),
                            const SizedBox(height: 9),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final ic in kCategoryIcons) _iconTile(ic, c),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _label('Colour'),
                            const SizedBox(height: 9),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final hex in kCategoryColors)
                                  _colorSwatch(hex),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _label('Monthly budget (optional)'),
                            const SizedBox(height: 7),
                            TextField(
                              controller: _budget,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              cursorColor: AppColors.brand,
                              style: AppText.mono(15, FontWeight.w500),
                              decoration: InputDecoration(
                                isDense: true,
                                filled: true,
                                fillColor: AppColors.card,
                                hintText: 'e.g. 2000 — blank for none',
                                hintStyle: AppText.ui(15, FontWeight.w400,
                                    color: AppColors.muted),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 15, vertical: 13),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.field),
                                  borderSide: BorderSide(color: AppColors.hairline),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.field),
                                  borderSide:
                                      const BorderSide(color: AppColors.brand),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            PrimaryButton(
                              label: editing ? 'Save changes' : 'Add category',
                              onTap: () => _save(n),
                            ),
                            if (editing && s.categories.length > 1) ...[
                              const SizedBox(height: 12),
                              _deleteButton(n, s.catEditorId),
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
        if (_confirming)
          ConfirmOverlay(
            title: 'Delete ${s.categoryById(s.catEditorId).name}?',
            message:
                'Transactions in this category will be moved to your first category.',
            confirmLabel: 'Delete',
            onCancel: () => setState(() => _confirming = false),
            onConfirm: () => n.deleteCategoryById(s.catEditorId),
          ),
      ],
    );
  }

  void _save(LedgerNotifier n) {
    if (_name.text.trim().isEmpty) {
      setState(() => _invalid = true);
      return;
    }
    n.saveCategory(
      name: _name.text,
      icon: _icon,
      color: _color,
      budget: parseAmount(_budget.text),
    );
  }

  Widget _preview(Color c) => Center(
    child: Column(
      children: [
        Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hexColor('${_color}29'),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(iconFor(_icon), size: 30, color: c),
        ),
        const SizedBox(height: 8),
        Text(
          _name.text.trim().isEmpty ? 'New category' : _name.text.trim(),
          style: AppText.ui(14, FontWeight.w600),
        ),
      ],
    ),
  );

  Widget _label(String text) =>
      Text(text, style: AppText.ui(12, FontWeight.w600, color: AppColors.muted));

  Widget _nameField(Color c) => TextField(
    controller: _name,
    onChanged: (_) => setState(() => _invalid = false),
    cursorColor: AppColors.brand,
    style: AppText.ui(15, FontWeight.w500),
    decoration: InputDecoration(
      isDense: true,
      filled: true,
      fillColor: AppColors.card,
      hintText: 'e.g. Coffee',
      hintStyle: AppText.ui(15, FontWeight.w400, color: AppColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: BorderSide(
          color: _invalid ? AppColors.expense : AppColors.hairline,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: const BorderSide(color: AppColors.brand),
      ),
    ),
  );

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
          color: selected ? hexColor('${_color}29') : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.tileMed),
          border: Border.all(
            color: selected ? c : AppColors.hairline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Icon(
          iconFor(ligature),
          size: 22,
          color: selected ? c : AppColors.text,
        ),
      ),
    );
  }

  Widget _colorSwatch(String hex) {
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
            color: selected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 18, color: Colors.black)
            : null,
      ),
    );
  }

  Widget _deleteButton(LedgerNotifier n, String id) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => setState(() => _confirming = true),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.expense.withValues(alpha: 0.4)),
      ),
      child: Text(
        'Delete category',
        style: AppText.ui(15, FontWeight.w600, color: AppColors.expense),
      ),
    ),
  );

}
