import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';

class CreateAssignmentFab extends StatelessWidget {
  final VoidCallback? onPressed;

  const CreateAssignmentFab({
    super.key,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      elevation: 8,
      icon: const Icon(Icons.add),
      label: const Text(
        'New Assignment',
        style: TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
