import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/services/class_management_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/widgets/global_app_scaffold.dart';
import '../widgets/class_card.dart';
import '../widgets/create_class_dialog.dart';
import 'class_details_page.dart';

// Provider for class management service
final classManagementServiceProvider = Provider<ClassManagementService>((ref) {
  return ClassManagementService();
});

// Provider for user classes
final userClassesProvider = FutureProvider<List<ClassModel>>((ref) async {
  final service = ref.read(classManagementServiceProvider);
  return await service.getUserClasses();
});

class ClassManagementPage extends ConsumerStatefulWidget {
  const ClassManagementPage({super.key});

  @override
  ConsumerState<ClassManagementPage> createState() =>
      _ClassManagementPageState();
}

class _ClassManagementPageState extends ConsumerState<ClassManagementPage> {
  @override
  Widget build(BuildContext context) {
    final userClassesAsync = ref.watch(userClassesProvider);
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.user;

    return GlobalAppScaffold(
      title: 'Class Management',
      actions: [
        if (currentUser?.userType == UserType.teacher)
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateClassDialog(),
            tooltip: 'Create Class',
          ),
      ],
      child: Container(
        color: AppTheme.backgroundColor,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(userClassesProvider);
          },
          child: userClassesAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, stack) => _buildErrorState(error.toString()),
            data: (classes) => _buildClassList(classes, currentUser),
          ),
        ),
      ),
    );
  }

  Widget _buildClassList(List<ClassModel> classes, User? currentUser) {
    if (classes.isEmpty) {
      return _buildEmptyState(currentUser);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: classes.length,
      itemBuilder: (context, index) {
        final classModel = classes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClassCard(
            classModel: classModel,
            onTap: () => _navigateToClassDetails(classModel),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(User? currentUser) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            currentUser?.userType == UserType.teacher
                ? 'No classes assigned yet'
                : 'You are not enrolled in any classes',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentUser?.userType == UserType.teacher
                ? 'Create a new class or contact your administrator'
                : 'Contact your teacher for class enrollment',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          if (currentUser?.userType == UserType.teacher) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateClassDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Class'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ref.invalidate(userClassesProvider);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToClassDetails(ClassModel classModel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ClassDetailsPage(classModel: classModel),
      ),
    );
  }

  void _showCreateClassDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateClassDialog(
        onClassCreated: () {
          ref.invalidate(userClassesProvider);
        },
      ),
    );
  }
}
