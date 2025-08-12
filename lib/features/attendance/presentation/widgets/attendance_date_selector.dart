import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_theme.dart';

class AttendanceDateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateChanged;

  const AttendanceDateSelector({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final startOfWeek = _getStartOfWeek(selectedDate);
    final days =
        List<DateTime>.generate(7, (i) => startOfWeek.add(Duration(days: i)));

    return SizedBox(
      height: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month/Year header
          Row(
            children: [
              Text(
                DateFormat('MMMM yyyy').format(selectedDate),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatWeekRange(startOfWeek),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final date = days[index];
                final isSelected = _isSameDay(date, selectedDate);
                final isToday = _isSameDay(date, DateTime.now());
                final isWeekend = date.weekday == DateTime.saturday ||
                    date.weekday == DateTime.sunday;

                return GestureDetector(
                  onTap: () => onDateChanged(date),
                  child: Container(
                    width: 64,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : isToday
                              ? AppTheme.primaryColor.withValues(alpha: 0.1)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isToday && !isSelected
                          ? Border.all(color: AppTheme.primaryColor, width: 1)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE').format(date),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : isWeekend
                                    ? Colors.grey[600]
                                    : AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('d').format(date),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : isWeekend
                                    ? Colors.grey[600]
                                    : AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  DateTime _getStartOfWeek(DateTime date) {
    // Monday as start of week
    final int daysToMonday = date.weekday - DateTime.monday; // 0 for Monday
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: daysToMonday));
  }

  String _formatWeekRange(DateTime startOfWeek) {
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    final sameMonth = startOfWeek.month == endOfWeek.month;
    if (sameMonth) {
      return '${DateFormat('MMM d').format(startOfWeek)} - ${DateFormat('d').format(endOfWeek)}';
    }
    return '${DateFormat('MMM d').format(startOfWeek)} - ${DateFormat('MMM d').format(endOfWeek)}';
  }
}
