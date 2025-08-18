import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../core/constants/app_theme.dart';
import '../widgets/formula_template_card.dart';
import '../widgets/formula_template_stats.dart';
import 'formula_builder_page.dart';

class FormulaTemplatesMainPage extends ConsumerStatefulWidget {
  const FormulaTemplatesMainPage({super.key});

  @override
  ConsumerState<FormulaTemplatesMainPage> createState() =>
      _FormulaTemplatesMainPageState();
}

class _FormulaTemplatesMainPageState
    extends ConsumerState<FormulaTemplatesMainPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedScope = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isAdmin = user.role == UserRole.admin;
    final isTeacher = user.userType == UserType.teacher;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Grading Formulas',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showFormulaHelp(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(context, value, user),
            itemBuilder: (context) => [
              if (isAdmin) ...[
                const PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    leading: Icon(Icons.upload_file),
                    title: Text('Import Templates'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    leading: Icon(Icons.download),
                    title: Text('Export Templates'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'bulk_actions',
                  child: ListTile(
                    leading: Icon(Icons.checklist),
                    title: Text('Bulk Actions'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Formula Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Scope Filter
              if (isAdmin) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Text(
                        'Scope: ',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      DropdownButton<String>(
                        value: _selectedScope,
                        dropdownColor: AppTheme.primaryColor,
                        style: const TextStyle(color: Colors.white),
                        underline: Container(),
                        items: const [
                          DropdownMenuItem(
                              value: 'all', child: Text('All Scopes')),
                          DropdownMenuItem(
                              value: 'school', child: Text('School Level')),
                          DropdownMenuItem(
                              value: 'period', child: Text('Period Level')),
                          DropdownMenuItem(
                              value: 'subject', child: Text('Subject Level')),
                          DropdownMenuItem(
                              value: 'class_offering',
                              child: Text('Class Level')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedScope = value ?? 'all';
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],

              // Tab Bar
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  const Tab(text: 'Active Templates'),
                  const Tab(text: 'My Templates'),
                  if (isAdmin) const Tab(text: 'Draft Templates'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Stats Section
          if (isTeacher || isAdmin) const FormulaTemplateStats(),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTemplateList('active'),
                _buildTemplateList('my_templates'),
                if (isAdmin) _buildTemplateList('drafts'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: (isTeacher || isAdmin)
          ? FloatingActionButton.extended(
              onPressed: () => _createNewTemplate(context, user),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New Formula'),
            )
          : null,
    );
  }

  Widget _buildTemplateList(String type) {
    final templates = _getMockTemplates(type);

    if (templates.isEmpty) {
      return _buildEmptyState(type);
    }

    return RefreshIndicator(
      onRefresh: () async {
        // TODO: Implement refresh logic
        await Future.delayed(const Duration(seconds: 1));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: templates.length,
        itemBuilder: (context, index) {
          final template = templates[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FormulaTemplateCard(
              template: template,
              onTap: () => _navigateToTemplateDetail(context, template),
              onEdit: () => _editTemplate(context, template),
              onDuplicate: () => _duplicateTemplate(context, template),
              onDelete: () => _deleteTemplate(context, template),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String type) {
    String message;
    String buttonText;
    IconData icon;

    switch (type) {
      case 'active':
        message = 'No active formula templates found';
        buttonText = 'Browse Templates';
        icon = Icons.functions;
        break;
      case 'my_templates':
        message = 'You haven\'t created any templates yet';
        buttonText = 'Create First Template';
        icon = Icons.add_box_outlined;
        break;
      case 'drafts':
        message = 'No draft templates found';
        buttonText = 'Create Draft';
        icon = Icons.drafts;
        break;
      default:
        message = 'No templates found';
        buttonText = 'Create Template';
        icon = Icons.functions;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () =>
                _createNewTemplate(context, ref.read(authStateProvider).user!),
            icon: const Icon(Icons.add),
            label: Text(buttonText),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action, User user) {
    switch (action) {
      case 'import':
        _importTemplates(context);
        break;
      case 'export':
        _exportTemplates(context);
        break;
      case 'bulk_actions':
        _showBulkActions(context);
        break;
      case 'settings':
        _navigateToSettings(context);
        break;
    }
  }

  void _showFormulaHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Formula Help'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Components Available:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• tugas_harian - Daily assignments average'),
              Text('• ulangan_harian - Regular tests average'),
              Text('• uts - Mid-semester exam'),
              Text('• uas - Final semester exam'),
              SizedBox(height: 16),
              Text(
                'Example Formula:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                  '0.25 * tugas_harian + 0.25 * ulangan_harian + 0.2 * uts + 0.3 * uas'),
              SizedBox(height: 16),
              Text(
                'Conditions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Use IF statements for conditional grading'),
              Text('Example: IF uas < 60 THEN uas ELSE formula'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _createNewTemplate(BuildContext context, User user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FormulaBuilderPage(scope: 'school'),
      ),
    );
  }

  void _navigateToTemplateDetail(
      BuildContext context, MockFormulaTemplate template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormulaTemplateDetailPage(template: template),
      ),
    );
  }

  void _editTemplate(BuildContext context, MockFormulaTemplate template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormulaBuilderPage(
          scope: template.scope.toLowerCase(),
          existingFormulaId: template.id,
        ),
      ),
    );
  }

  void _duplicateTemplate(BuildContext context, MockFormulaTemplate template) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Template "${template.name}" duplicated'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _deleteTemplate(BuildContext context, MockFormulaTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Are you sure you want to delete "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Template deleted'),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _importTemplates(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import functionality coming soon')),
    );
  }

  void _exportTemplates(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export functionality coming soon')),
    );
  }

  void _showBulkActions(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bulk actions coming soon')),
    );
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FormulaSettingsPage(),
      ),
    );
  }

  // Mock data - replace with actual API calls
  List<MockFormulaTemplate> _getMockTemplates(String type) {
    final allTemplates = [
      MockFormulaTemplate(
        id: '1',
        name: 'Standard Islamic School Formula',
        description: '25% Tugas + 25% Ulangan + 20% UTS + 30% UAS',
        formula:
            '0.25 * tugas_harian + 0.25 * ulangan_harian + 0.2 * uts + 0.3 * uas',
        scope: 'School',
        isActive: true,
        isDraft: false,
        createdBy: 'Admin',
        usageCount: 15,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      MockFormulaTemplate(
        id: '2',
        name: 'Mathematics Focus Formula',
        description: 'Higher weight on final exam for math subjects',
        formula:
            '0.2 * tugas_harian + 0.2 * ulangan_harian + 0.15 * uts + 0.45 * uas',
        scope: 'Subject',
        isActive: true,
        isDraft: false,
        createdBy: 'Teacher',
        usageCount: 8,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
      MockFormulaTemplate(
        id: '3',
        name: 'Draft Formula V2',
        description: 'Experimental formula with conditions',
        formula:
            'IF uas < 60 THEN uas ELSE 0.3 * tugas_harian + 0.3 * ulangan_harian + 0.4 * uas',
        scope: 'Class',
        isActive: false,
        isDraft: true,
        createdBy: 'Teacher',
        usageCount: 0,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ];

    switch (type) {
      case 'active':
        return allTemplates.where((t) => t.isActive && !t.isDraft).toList();
      case 'my_templates':
        return allTemplates.where((t) => t.createdBy == 'Teacher').toList();
      case 'drafts':
        return allTemplates.where((t) => t.isDraft).toList();
      default:
        return allTemplates;
    }
  }
}

// Mock data model
class MockFormulaTemplate {
  final String id;
  final String name;
  final String description;
  final String formula;
  final String scope;
  final bool isActive;
  final bool isDraft;
  final String createdBy;
  final int usageCount;
  final DateTime createdAt;

  MockFormulaTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.formula,
    required this.scope,
    required this.isActive,
    required this.isDraft,
    required this.createdBy,
    required this.usageCount,
    required this.createdAt,
  });

  String get statusText {
    if (isDraft) return 'Draft';
    if (isActive) return 'Active';
    return 'Inactive';
  }

  Color get statusColor {
    if (isDraft) return AppTheme.warningColor;
    if (isActive) return AppTheme.successColor;
    return AppTheme.textSecondary;
  }
}

// Placeholder pages
class FormulaTemplateDetailPage extends StatelessWidget {
  final MockFormulaTemplate template;

  const FormulaTemplateDetailPage({super.key, required this.template});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(template.name)),
      body: Center(child: Text('Template Detail - ${template.name}')),
    );
  }
}

class FormulaSettingsPage extends StatelessWidget {
  const FormulaSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Formula Settings')),
      body: const Center(child: Text('Formula Settings - To be implemented')),
    );
  }
}
