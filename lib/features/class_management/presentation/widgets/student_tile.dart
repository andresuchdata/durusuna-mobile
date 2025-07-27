import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/user.dart';

class StudentTile extends StatelessWidget {
  final User student;
  final VoidCallback onTap;

  const StudentTile({
    super.key,
    required this.student,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.successColor,
          backgroundImage: student.avatarUrl != null
              ? NetworkImage(student.avatarUrl!)
              : null,
          child: student.avatarUrl == null
              ? Text(
                  '${student.firstName[0]}${student.lastName[0]}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          '${student.firstName} ${student.lastName}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(student.email),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
