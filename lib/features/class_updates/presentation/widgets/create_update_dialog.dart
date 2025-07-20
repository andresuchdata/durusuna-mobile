import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/class_update.dart';
import '../../../../shared/services/class_updates_service.dart';
import '../../../../shared/widgets/loading_button.dart';

class CreateUpdateDialog extends ConsumerStatefulWidget {
  final String classId;
  final ClassUpdate? editingUpdate;
  final VoidCallback onUpdateCreated;

  const CreateUpdateDialog({
    super.key,
    required this.classId,
    this.editingUpdate,
    required this.onUpdateCreated,
  });

  @override
  ConsumerState<CreateUpdateDialog> createState() => _CreateUpdateDialogState();
}

class _CreateUpdateDialogState extends ConsumerState<CreateUpdateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  
  UpdateType _selectedType = UpdateType.announcement;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.editingUpdate != null) {
      _titleController.text = widget.editingUpdate!.title ?? '';
      _contentController.text = widget.editingUpdate!.content;
      _selectedType = widget.editingUpdate!.updateType;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(classUpdatesServiceProvider);
      
      if (widget.editingUpdate != null) {
        // Update existing
        await service.updateClassUpdate(
          updateId: widget.editingUpdate!.id,
          title: _titleController.text.trim().isNotEmpty 
              ? _titleController.text.trim() 
              : null,
          content: _contentController.text.trim(),
          updateType: _selectedType,
        );
      } else {
        // Create new
        await service.createClassUpdate(
          classId: widget.classId,
          title: _titleController.text.trim().isNotEmpty 
              ? _titleController.text.trim() 
              : null,
          content: _contentController.text.trim(),
          updateType: _selectedType,
        );
      }

      widget.onUpdateCreated();
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.editingUpdate != null 
                ? 'Update edited successfully' 
                : 'Update created successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${widget.editingUpdate != null ? 'edit' : 'create'} update: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    widget.editingUpdate != null ? 'Edit Update' : 'Create Update',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Update Type Selector
              const Text(
                'Update Type',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: UpdateType.values.map((type) {
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedType = type),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedType == type
                              ? AppTheme.primaryColor
                              : AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedType == type
                                ? AppTheme.primaryColor
                                : AppTheme.borderColor,
                          ),
                        ),
                        child: Text(
                          _getUpdateTypeDisplay(type),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _selectedType == type
                                ? Colors.white
                                : AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 24),
              
              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title (Optional)',
                  hintText: 'Enter a title for your update',
                ),
                maxLength: 100,
              ),
              
              const SizedBox(height: 16),
              
              // Content Field
              Expanded(
                child: TextFormField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    hintText: 'What would you like to share with your class?',
                    alignLabelWithHint: true,
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter some content';
                    }
                    return null;
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Attachment Section (Placeholder)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 32,
                      color: AppTheme.textTertiary,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add attachments (Coming soon)',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: LoadingButton(
                      onPressed: _handleSubmit,
                      isLoading: _isLoading,
                      child: Text(widget.editingUpdate != null ? 'Update' : 'Post'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getUpdateTypeDisplay(UpdateType type) {
    switch (type) {
      case UpdateType.announcement:
        return '📢 News';
      case UpdateType.homework:
        return '📚 Homework';
      case UpdateType.reminder:
        return '⏰ Reminder';
      case UpdateType.event:
        return '📅 Event';
    }
  }
} 