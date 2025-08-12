import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';

class TimeSettingsCard extends StatelessWidget {
  final TextEditingController startTimeController;
  final TextEditingController endTimeController;
  final bool allowLateAttendance;
  final TextEditingController lateThresholdController;
  final Function(bool) onAllowLateChanged;
  final Function(TextEditingController) onTimeSelected;

  const TimeSettingsCard({
    super.key,
    required this.startTimeController,
    required this.endTimeController,
    required this.allowLateAttendance,
    required this.lateThresholdController,
    required this.onAllowLateChanged,
    required this.onTimeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Time Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Attendance Hours
            const Text(
              'Attendance Hours',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => onTimeSelected(startTimeController),
                    child: AbsorbPointer(
                      child: TextField(
                        controller: startTimeController,
                        decoration: InputDecoration(
                          labelText: 'Start Time',
                          hintText: '08:00',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.schedule),
                          suffixIcon: const Icon(Icons.arrow_drop_down),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onTimeSelected(endTimeController),
                    child: AbsorbPointer(
                      child: TextField(
                        controller: endTimeController,
                        decoration: InputDecoration(
                          labelText: 'End Time',
                          hintText: '15:00',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.schedule),
                          suffixIcon: const Icon(Icons.arrow_drop_down),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Info about attendance hours
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'These times are used to determine if a student is late when marking attendance via GPS.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
