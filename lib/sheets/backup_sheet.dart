import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/ledger_notifier.dart';
import '../theme/tokens.dart';
import '../widgets/confirm_overlay.dart';
import '../widgets/enter_animations.dart';
import '../widgets/primary_button.dart';
import 'sheet_chrome.dart';

/// Backup & Restore: copy all data out as JSON, or paste a backup back in to
/// restore / move to a new device. Mounted while `backupOpen` is true.
class BackupSheet extends ConsumerStatefulWidget {
  const BackupSheet({super.key});

  @override
  ConsumerState<BackupSheet> createState() => _BackupSheetState();
}

class _BackupSheetState extends ConsumerState<BackupSheet> {
  late final TextEditingController _import;
  String? _error;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _import = TextEditingController();
  }

  @override
  void dispose() {
    _import.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(ledgerProvider);
    final n = ref.read(ledgerProvider.notifier);
    final backup = n.exportBackup();

    return Stack(
      children: [
        Positioned.fill(
          child: EnterFade(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: n.closeBackup,
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
                      title: 'Backup & Restore',
                      onCancel: n.closeBackup,
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your data lives only on this device. Copy this '
                              'backup somewhere safe (Notes, email, AirDrop), '
                              'then paste it back below to restore or move to a '
                              'new phone.',
                              style: AppText.ui(13, FontWeight.w400,
                                  color: AppColors.muted, height: 1.45),
                            ),
                            const SizedBox(height: 18),
                            _eyebrow('EXPORT'),
                            const SizedBox(height: 6),
                            Text(
                              '${s.accounts.length} accounts · '
                              '${s.transactions.length} transactions · '
                              '${s.categories.length} categories',
                              style: AppText.muted12,
                            ),
                            const SizedBox(height: 9),
                            Container(
                              height: 110,
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.deep,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.field),
                                border: Border.all(color: AppColors.hairline),
                              ),
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  backup,
                                  style: AppText.mono(10.5, FontWeight.w400,
                                      color: AppColors.muted),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            PrimaryButton(
                              label: 'Copy backup',
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: backup));
                                n.flashToast('Backup copied');
                              },
                            ),
                            const SizedBox(height: 24),
                            _eyebrow('RESTORE'),
                            const SizedBox(height: 6),
                            Text(
                              'Paste a backup to replace everything on this '
                              'device.',
                              style: AppText.muted12,
                            ),
                            const SizedBox(height: 9),
                            TextField(
                              controller: _import,
                              onChanged: (_) {
                                if (_error != null) {
                                  setState(() => _error = null);
                                }
                              },
                              maxLines: 4,
                              cursorColor: AppColors.brand,
                              style: AppText.mono(12, FontWeight.w400),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppColors.card,
                                hintText: 'Paste your backup JSON here',
                                hintStyle: AppText.ui(13, FontWeight.w400,
                                    color: AppColors.muted),
                                contentPadding: const EdgeInsets.all(13),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.field),
                                  borderSide: BorderSide(
                                    color: _error != null
                                        ? AppColors.expense
                                        : AppColors.hairline,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.field),
                                  borderSide:
                                      const BorderSide(color: AppColors.brand),
                                ),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 7),
                              Text(
                                _error!,
                                style: AppText.ui(12, FontWeight.w600,
                                    color: AppColors.expense),
                              ),
                            ],
                            const SizedBox(height: 12),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (_import.text.trim().isEmpty) {
                                  setState(() =>
                                      _error = 'Paste a backup first.');
                                  return;
                                }
                                setState(() => _confirming = true);
                              },
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
                                  'Restore (replaces all data)',
                                  style: AppText.ui(15, FontWeight.w600,
                                      color: AppColors.expense),
                                ),
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
            title: 'Restore from backup?',
            message: 'This replaces ALL current data on this device with the '
                "pasted backup. This can't be undone.",
            confirmLabel: 'Restore',
            onCancel: () => setState(() => _confirming = false),
            onConfirm: () {
              final err = n.restoreBackup(_import.text);
              if (err != null) {
                setState(() {
                  _error = err;
                  _confirming = false;
                });
              } else {
                n.closeBackup();
              }
            },
          ),
      ],
    );
  }

  Widget _eyebrow(String text) =>
      Text(text, style: AppText.eyebrow().copyWith(fontSize: 11));
}
