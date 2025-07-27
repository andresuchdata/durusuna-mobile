import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/user.dart';

class TeacherTile extends StatelessWidget {
  final User teacher;
  final VoidCallback onTap;

  const TeacherTile({
    super.key,
    required this.teacher,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor,
          backgroundImage: teacher.avatarUrl != null
              ? NetworkImage(teacher.avatarUrl!)
              : null,
          child: teacher.avatarUrl == null
              ? Text(
                  '${teacher.firstName[0]}${teacher.lastName[0]}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          '${teacher.firstName} ${teacher.lastName}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(teacher.email),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
