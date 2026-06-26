import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/statement.dart';
import '../theme/tokens.dart';

/// An in-sheet month calendar that stays inside the phone frame — unlike the
/// Material `showDatePicker` dialog, which renders at the root window and spills
/// outside the 393×812 mock. Sunday-first grid; tap a day to pick it.
class MonthCalendar extends StatefulWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onPick;

  const MonthCalendar({
    super.key,
    required this.selected,
    required this.onPick,
  });

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late DateTime _focused; // first day of the displayed month

  @override
  void initState() {
    super.initState();
    _focused = DateTime(widget.selected.year, widget.selected.month);
  }

  void _shift(int months) =>
      setState(() => _focused = DateTime(_focused.year, _focused.month + months));

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final cells = monthGridCells(_focused.year, _focused.month);
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navButton(Symbols.chevron_left_rounded, () => _shift(-1)),
              Text(
                '${monthAbbrev(_focused.month)} ${_focused.year}',
                style: AppText.ui(16, FontWeight.w700),
              ),
              _navButton(Symbols.chevron_right_rounded, () => _shift(1)),
            ],
          ),
        ),
        Row(
          children: [
            for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: AppText.ui(11, FontWeight.w700, color: AppColors.muted),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (final c in cells)
              if (c == null)
                const SizedBox()
              else
                _dayCell(c, now),
          ],
        ),
        const SizedBox(height: 14),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () =>
              widget.onPick(DateTime(now.year, now.month, now.day)),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.keypad,
              borderRadius: BorderRadius.circular(AppRadii.field),
              border: Border.all(color: AppColors.hairlineStrong),
            ),
            child: Text('Today', style: AppText.ui(14, FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _dayCell(int day, DateTime now) {
    final date = DateTime(_focused.year, _focused.month, day);
    final selected = _sameDay(date, widget.selected);
    final isToday = _sameDay(date, now);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onPick(date),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          border: !selected && isToday
              ? Border.all(color: AppColors.brand.withValues(alpha: 0.5))
              : null,
        ),
        child: Text(
          '$day',
          style: AppText.mono(
            14,
            selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.onBrand : AppColors.text,
          ),
        ),
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback onTap) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: AppColors.text),
    ),
  );
}
