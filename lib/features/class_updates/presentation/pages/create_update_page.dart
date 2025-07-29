import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/class_update.dart';
import '../../../../shared/models/attachment.dart';
import '../../../../shared/services/class_updates_service.dart';
import '../../../../shared/services/media_service.dart';
import '../../../../shared/widgets/loading_button.dart';
import '../widgets/attachment_preview_widget.dart';
import '../widgets/media_upload_widget.dart';

class CreateUpdatePage extends ConsumerStatefulWidget {
  final String classId;
  final ClassUpdate? editingUpdate;

  const CreateUpdatePage({
    super.key,
    required this.classId,
    this.editingUpdate,
  });

  @override
  ConsumerState<CreateUpdatePage> createState() => _CreateUpdatePageState();
}

class _CreateUpdatePageState extends ConsumerState<CreateUpdatePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _scrollController = ScrollController();

  UpdateType _selectedType = UpdateType.announcement;
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;
  bool _isUploadingAttachments = false;
  List<Attachment> _attachments = [];

  @override
  void initState() {
    super.initState();
    if (widget.editingUpdate != null) {
      _titleController.text = widget.editingUpdate!.title ?? '';
      _contentController.text = widget.editingUpdate!.content;
      _selectedType = widget.editingUpdate!.updateType;

      // Safely convert existing attachments from JSON format
      _attachments = <Attachment>[];
      try {
        if (widget.editingUpdate!.attachments != null &&
            widget.editingUpdate!.attachments is List) {
          final attachmentList = widget.editingUpdate!.attachments as List;
          for (final item in attachmentList) {
            try {
              if (item != null && item is Map<String, dynamic>) {
                final attachment = Attachment.fromJson(item);
                _attachments.add(attachment);
              }
            } catch (e) {
              debugPrint('Error parsing existing attachment: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('Error parsing existing attachments: $e');
      }
    }

    // Listen for changes to track unsaved content
    _titleController.addListener(_onContentChanged);
    _contentController.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  void _onAttachmentsChanged(List<Attachment> attachments) {
    setState(() {
      _attachments = attachments;
      _hasUnsavedChanges = true;
      // Reset upload state when attachments change (upload completed)
      _isUploadingAttachments = false;
    });
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
            'You have unsaved changes. Are you sure you want to leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _saveDraft() async {
    // TODO: Implement draft saving
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Draft saved locally')),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // Double-check that no uploads are in progress
    if (_isUploadingAttachments) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for all attachments to finish uploading'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = ref.read(classUpdatesServiceProvider);

      if (widget.editingUpdate != null) {
        await service.updateClassUpdate(
          updateId: widget.editingUpdate!.id,
          title: _titleController.text.trim().isNotEmpty
              ? _titleController.text.trim()
              : null,
          content: _contentController.text.trim(),
          updateType: _selectedType,
          attachments: _attachments.map((a) => a.toJson()).toList(),
        );
      } else {
        await service.createClassUpdate(
          classId: widget.classId,
          title: _titleController.text.trim().isNotEmpty
              ? _titleController.text.trim()
              : null,
          content: _contentController.text.trim(),
          updateType: _selectedType,
          attachments: _attachments.map((a) => a.toJson()).toList(),
        );
      }

      setState(() => _hasUnsavedChanges = false);

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.editingUpdate != null
                ? 'Update edited successfully'
                : 'Update posted successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to ${widget.editingUpdate != null ? 'edit' : 'post'} update: $e'),
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
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              widget.editingUpdate != null ? 'Edit Update' : 'Create Update'),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimary,
          leading: IconButton(
            onPressed: () async {
              if (await _onWillPop()) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.close),
          ),
          actions: [
            if (_hasUnsavedChanges)
              TextButton(
                onPressed: _saveDraft,
                child: const Text('Save Draft'),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              // Main content area
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Update Type Selector
                      const Text(
                        'Update Type',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Type selection cards - 2x2 grid for better touch targets
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 2.2,
                        children: UpdateType.values.map((type) {
                          final isSelected = _selectedType == type;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedType = type),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : AppTheme.borderColor,
                                  width: 2,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppTheme.primaryColor
                                              .withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _getUpdateTypeIcon(type),
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getUpdateTypeLabel(type),
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : AppTheme.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 32),

                      // Title Field
                      const Text(
                        'Title (Optional)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: 'Enter a title for your update...',
                          filled: true,
                          fillColor: AppTheme.backgroundColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.primaryColor,
                              width: 2,
                            ),
                          ),
                          counterText: '${_titleController.text.length}/100',
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        maxLength: 100,
                        style: const TextStyle(fontSize: 16),
                      ),

                      const SizedBox(height: 24),

                      // Content Field
                      const Text(
                        'Content',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _contentController,
                        decoration: InputDecoration(
                          hintText:
                              'What would you like to share with your class?',
                          filled: true,
                          fillColor: AppTheme.backgroundColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.primaryColor,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 8,
                        minLines: 4,
                        style: const TextStyle(fontSize: 16),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter some content';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Media Upload Section
                      MediaUploadWidget(
                        classId: widget.classId,
                        currentAttachments: _attachments,
                        onAttachmentsChanged: _onAttachmentsChanged,
                        onUploadProgress: (progress) {
                          print('📤 Upload progress: ${progress.progress}');
                          print('📤 Upload status: ${progress.status}');
                          print('📤 Upload completed: ${progress.isCompleted}');
                          print('📤 Upload has error: ${progress.hasError}');

                          setState(() {
                            // Track upload state - uploading if progress < 1.0 and no error
                            _isUploadingAttachments =
                                !progress.isCompleted && !progress.hasError;
                            print(
                                '🔒 Button disabled: $_isUploadingAttachments');
                          });

                          // Handle upload progress if needed
                          if (progress.hasError) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Upload error: ${progress.error}'),
                                backgroundColor: AppTheme.errorColor,
                              ),
                            );
                          }
                        },
                      ),

                      const SizedBox(height: 100), // Extra space for bottom bar
                    ],
                  ),
                ),
              ),

              // Bottom action bar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      // Cancel button
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          onPressed: () async {
                            if (await _onWillPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: AppTheme.borderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Post button
                      Expanded(
                        flex: 2,
                        child: LoadingButton(
                          onPressed:
                              _isUploadingAttachments ? null : _handleSubmit,
                          isLoading: _isLoading,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isUploadingAttachments
                                ? AppTheme.textTertiary
                                : AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            _isUploadingAttachments
                                ? 'Uploading...'
                                : (widget.editingUpdate != null
                                    ? 'Update'
                                    : 'Post'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getUpdateTypeIcon(UpdateType type) {
    switch (type) {
      case UpdateType.announcement:
        return '📢';
      case UpdateType.homework:
        return '📚';
      case UpdateType.reminder:
        return '⏰';
      case UpdateType.event:
        return '📅';
    }
  }

  String _getUpdateTypeLabel(UpdateType type) {
    switch (type) {
      case UpdateType.announcement:
        return 'News';
      case UpdateType.homework:
        return 'Homework';
      case UpdateType.reminder:
        return 'Reminder';
      case UpdateType.event:
        return 'Event';
    }
  }
}
