import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/constants/app_theme.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../widgets/loading_button.dart';

class ProfileCard extends ConsumerStatefulWidget {
  final User user;
  final bool isOnline;
  final DateTime? lastSeen;
  final VoidCallback? onStartChat;
  final VoidCallback? onCall;
  final VoidCallback? onVideoCall;
  final VoidCallback? onBlock;
  final bool showEditButton;
  final bool isEditMode;

  const ProfileCard({
    super.key,
    required this.user,
    this.isOnline = false,
    this.lastSeen,
    this.onStartChat,
    this.onCall,
    this.onVideoCall,
    this.onBlock,
    this.showEditButton = false,
    this.isEditMode = false,
  });

  @override
  ConsumerState<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<ProfileCard> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedAvatarUrl;
  File? _selectedImageFile;
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.isEditMode;
    _firstNameController.text = widget.user.firstName;
    _lastNameController.text = widget.user.lastName;
    _phoneController.text = widget.user.phone ?? '';
    _selectedAvatarUrl = widget.user.avatarUrl;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _navigateToEditProfile(BuildContext context) {
    setState(() {
      _isEditMode = true;
    });
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImageFile = File(image.path);
          _selectedAvatarUrl =
              null; // Clear existing URL when new file is selected
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImageFile = File(image.path);
          _selectedAvatarUrl =
              null; // Clear existing URL when new file is selected
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to take photo: $e');
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImageFile == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post(
        '/uploads/file',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(_selectedImageFile!.path),
          'folder': 'avatars',
          'processImage': true,
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final fileInfo = data['file'] as Map<String, dynamic>;
        setState(() {
          _selectedAvatarUrl = fileInfo['url'] as String;
          _selectedImageFile = null; // Clear the file after successful upload
        });
        _showSuccessSnackBar('Profile picture uploaded successfully');
      } else {
        throw Exception('Upload failed with status: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to upload image: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload image first if a new one was selected
      if (_selectedImageFile != null) {
        await _uploadImage();
      }

      // Update profile with new data
      final authService = ref.read(authServiceProvider);
      final updatedUser = await authService.updateProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        avatarUrl: _selectedAvatarUrl,
      );

      _showSuccessSnackBar('Profile updated successfully');

      // Exit edit mode
      setState(() {
        _isEditMode = false;
      });

      // Close the modal if it's open with a small delay to show the snackbar
      if (Navigator.of(context).canPop()) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pop(updatedUser);
          }
        });
      } else {
        // If not in a modal, just exit edit mode
        setState(() {
          _isEditMode = false;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to update profile: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditMode = false;
      // Reset form values
      _firstNameController.text = widget.user.firstName;
      _lastNameController.text = widget.user.lastName;
      _phoneController.text = widget.user.phone ?? '';
      _selectedAvatarUrl = widget.user.avatarUrl;
      _selectedImageFile = null;
    });
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            if (_selectedAvatarUrl != null || _selectedImageFile != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedAvatarUrl = null;
                    _selectedImageFile = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          if (_isEditMode) ...[
            // Edit Mode UI
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Profile Picture Section
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppTheme.primaryColor,
                        backgroundImage: _selectedImageFile != null
                            ? FileImage(_selectedImageFile!)
                            : (_selectedAvatarUrl?.isNotEmpty == true
                                ? NetworkImage(_selectedAvatarUrl!)
                                    as ImageProvider
                                : null),
                        child: (_selectedImageFile == null &&
                                _selectedAvatarUrl?.isEmpty != false)
                            ? Text(
                                '${_firstNameController.text.isNotEmpty ? _firstNameController.text[0] : ''}${_lastNameController.text.isNotEmpty ? _lastNameController.text[0] : ''}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: IconButton(
                            onPressed:
                                _isUploading ? null : _showImageSourceDialog,
                            icon: _isUploading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.camera_alt,
                                    color: Colors.white),
                            iconSize: 20,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Form Fields
                  TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'First name is required';
                      }
                      if (value.trim().length < 2) {
                        return 'First name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Last name is required';
                      }
                      if (value.trim().length < 2) {
                        return 'Last name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _cancelEdit,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LoadingButton(
                          onPressed: _saveProfile,
                          isLoading: _isLoading,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Save',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            // View Mode UI
            // Profile Avatar with online indicator and edit button
            Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppTheme.primaryColor,
                  backgroundImage: widget.user.avatarUrl?.isNotEmpty == true
                      ? NetworkImage(widget.user.avatarUrl!)
                      : null,
                  child: widget.user.avatarUrl?.isEmpty != false
                      ? Text(
                          '${widget.user.firstName[0]}${widget.user.lastName[0]}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                if (widget.isOnline)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                if (widget.showEditButton)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: IconButton(
                        onPressed: () => _navigateToEditProfile(context),
                        icon: const Icon(Icons.edit, color: Colors.white),
                        iconSize: 20,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // User name
            Text(
              widget.user.displayName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),

            const SizedBox(height: 4),

            // User type and role
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getUserTypeDisplay(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Online status
            Text(
              _getStatusText(),
              style: TextStyle(
                fontSize: 14,
                color: widget.isOnline
                    ? AppTheme.successColor
                    : AppTheme.textSecondary,
              ),
            ),

            const SizedBox(height: 20),

            // User details
            if (widget.user.email.isNotEmpty) ...[
              _buildDetailRow(Icons.email, 'Email', widget.user.email),
              const SizedBox(height: 12),
            ],

            if (widget.user.phone?.isNotEmpty == true) ...[
              _buildDetailRow(Icons.phone, 'Phone', widget.user.phone!),
              const SizedBox(height: 12),
            ],

            if (widget.user.school?.name.isNotEmpty == true) ...[
              _buildDetailRow(Icons.school, 'School', widget.user.school!.name),
              const SizedBox(height: 20),
            ] else
              const SizedBox(height: 8),

            // Action buttons
            Row(
              children: [
                if (widget.onStartChat != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.onStartChat,
                      icon: const Icon(Icons.chat_bubble, size: 18),
                      label: const Text('Message'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                if (widget.onStartChat != null &&
                    (widget.onCall != null || widget.onVideoCall != null))
                  const SizedBox(width: 12),
                if (widget.onCall != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onCall,
                      icon: const Icon(Icons.call, size: 18),
                      label: const Text('Call'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                if (widget.onCall != null && widget.onVideoCall != null)
                  const SizedBox(width: 12),
                if (widget.onVideoCall != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onVideoCall,
                      icon: const Icon(Icons.videocam, size: 18),
                      label: const Text('Video'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Additional actions
            if (widget.onBlock != null)
              TextButton.icon(
                onPressed: widget.onBlock,
                icon: const Icon(Icons.block,
                    size: 18, color: AppTheme.errorColor),
                label: const Text(
                  'Block User',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
              ),

            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getUserTypeDisplay() {
    switch (widget.user.userType) {
      case UserType.teacher:
        return 'Teacher';
      case UserType.student:
        return 'Student';
      case UserType.parent:
        return 'Parent';
    }
  }

  String _getStatusText() {
    if (widget.isOnline) {
      return 'Online';
    } else if (widget.lastSeen != null) {
      return 'Last seen ${timeago.format(widget.lastSeen!)}';
    } else {
      return 'Offline';
    }
  }
}
