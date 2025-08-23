import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/class_model.dart';
import '../pages/class_details_page.dart' show classCountsProvider;

class ClassCard extends ConsumerWidget {
  final ClassModel classModel;
  final VoidCallback onTap;

  const ClassCard({
    super.key,
    required this.classModel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(classCountsProvider(classModel.id));
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor.withOpacity(0.05),
                AppTheme.primaryColor.withOpacity(0.02),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.class_,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          classModel.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (classModel.displayName != classModel.name)
                          Text(
                            classModel.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
              if (classModel.description != null) ...[
                const SizedBox(height: 12),
                Text(
                  classModel.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              countsAsync.when(
                loading: () => Row(
                  children: [
                    _buildInfoChip(
                      icon: Icons.people,
                      label: '${classModel.studentsCount ?? 0} Students',
                      color: AppTheme.successColor,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      icon: Icons.person,
                      label: '${classModel.teachersCount ?? 0} Teachers',
                      color: AppTheme.infoColor,
                    ),
                  ],
                ),
                error: (error, stack) => Row(
                  children: [
                    _buildInfoChip(
                      icon: Icons.people,
                      label: '${classModel.studentsCount ?? 0} Students',
                      color: AppTheme.successColor,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      icon: Icons.person,
                      label: '${classModel.teachersCount ?? 0} Teachers',
                      color: AppTheme.infoColor,
                    ),
                  ],
                ),
                data: (counts) => Row(
                  children: [
                    _buildInfoChip(
                      icon: Icons.people,
                      label: '${counts.studentCount} Students',
                      color: AppTheme.successColor,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      icon: Icons.person,
                      label: '${counts.teacherCount} Teachers',
                      color: AppTheme.infoColor,
                    ),
                  ],
                ),
              ),
              if (classModel.academicYear.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildInfoChip(
                  icon: Icons.calendar_today,
                  label: classModel.academicYear.isNotEmpty
                      ? classModel.academicYear
                      : 'Academic Year',
                  color: AppTheme.warningColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
