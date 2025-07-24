import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_theme.dart';
import '../services/avatar_service.dart';
import '../services/media_service.dart';
import '../models/user.dart';
import 'avatar_widget.dart';
import 'loading_button.dart';

class AvatarManager extends StatefulWidget {
  final String? currentAvatarUrl;
  final String? fallbackInitials;
  final IconData? fallbackIcon;
  final double radius;
  final bool showOnlineIndicator;
  final bool isOnline;

  // User avatar management
  final bool isUserAvatar;
  final Function(User)? onUserAvatarChanged;

  // Entity avatar management (for classes, groups, etc.)
  final String? entityType;
  final String? entityId;
  final Function(String)? onEntityAvatarChanged;

  // Customization
  final bool showChangeButton;
  final bool showRemoveButton;
  final bool enableTapToChange;
  final String? changeButtonText;
  final String? removeButtonText;
  final Color? backgroundColor;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  const AvatarManager({
    super.key,
    this.currentAvatarUrl,
    this.fallbackInitials,
    this.fallbackIcon,
    this.radius = 50,
    this.showOnlineIndicator = false,
    this.isOnline = false,
    this.isUserAvatar = true,
    this.onUserAvatarChanged,
    this.entityType,
    this.entityId,
    this.onEntityAvatarChanged,
    this.showChangeButton = true,
    this.showRemoveButton = true,
    this.enableTapToChange = true,
    this.changeButtonText,
    this.removeButtonText,
    this.backgroundColor,
    this.border,
    this.boxShadow,
  }) : assert(
          isUserAvatar || (entityType != null && entityId != null),
          'For non-user avatars, entityType and entityId must be provided',
        );

  /// Factory for user avatar management
  factory AvatarManager.user({
    required String firstName,
    required String lastName,
    String? currentAvatarUrl,
    double radius = 50,
    bool showOnlineIndicator = false,
    bool isOnline = false,
    Function(User)? onAvatarChanged,
    bool showChangeButton = true,
    bool showRemoveButton = true,
    bool enableTapToChange = true,
    String? changeButtonText,
    String? removeButtonText,
    Color? backgroundColor,
    Border? border,
    List<BoxShadow>? boxShadow,
  }) {
    final initials = '${firstName.isNotEmpty ? firstName[0].toUpperCase() : ''}'
        '${lastName.isNotEmpty ? lastName[0].toUpperCase() : ''}';

    return AvatarManager(
      currentAvatarUrl: currentAvatarUrl,
      fallbackInitials: initials.isNotEmpty ? initials : '?',
      radius: radius,
      showOnlineIndicator: showOnlineIndicator,
      isOnline: isOnline,
      isUserAvatar: true,
      onUserAvatarChanged: onAvatarChanged,
      showChangeButton: showChangeButton,
      showRemoveButton: showRemoveButton,
      enableTapToChange: enableTapToChange,
      changeButtonText: changeButtonText,
      removeButtonText: removeButtonText,
      backgroundColor: backgroundColor,
      border: border,
      boxShadow: boxShadow,
    );
  }

  /// Factory for entity avatar management (classes, groups, etc.)
  factory AvatarManager.entity({
    required String entityType,
    required String entityId,
    String? currentAvatarUrl,
    IconData? fallbackIcon = Icons.group,
    double radius = 50,
    Function(String)? onAvatarChanged,
    bool showChangeButton = true,
    bool showRemoveButton = true,
    bool enableTapToChange = true,
    String? changeButtonText,
    String? removeButtonText,
    Color? backgroundColor,
    Border? border,
    List<BoxShadow>? boxShadow,
  }) {
    return AvatarManager(
      currentAvatarUrl: currentAvatarUrl,
      fallbackIcon: fallbackIcon,
      radius: radius,
      isUserAvatar: false,
      entityType: entityType,
      entityId: entityId,
      onEntityAvatarChanged: onAvatarChanged,
      showChangeButton: showChangeButton,
      showRemoveButton: showRemoveButton,
      enableTapToChange: enableTapToChange,
      changeButtonText: changeButtonText,
      removeButtonText: removeButtonText,
      backgroundColor: backgroundColor,
      border: border,
      boxShadow: boxShadow,
    );
  }

  @override
  State<AvatarManager> createState() => _AvatarManagerState();
}

class _AvatarManagerState extends State<AvatarManager> {
  final AvatarService _avatarService = AvatarService();

  String? _currentAvatarUrl;
  bool _isLoading = false;
  String _loadingStatus = '';
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _currentAvatarUrl = widget.currentAvatarUrl;
  }

  @override
  void didUpdateWidget(covariant AvatarManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentAvatarUrl != oldWidget.currentAvatarUrl) {
      _currentAvatarUrl = widget.currentAvatarUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAvatar(),
        if (_isLoading) ...[
          const SizedBox(height: 16),
          _buildProgressIndicator(),
        ],
        if (!_isLoading &&
            (widget.showChangeButton || widget.showRemoveButton)) ...[
          const SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ],
    );
  }

  Widget _buildAvatar() {
    final avatar = Avatar(
      avatarUrl: _currentAvatarUrl,
      initials: widget.fallbackInitials,
      fallbackIcon: widget.fallbackIcon,
      radius: widget.radius,
      showOnlineIndicator: widget.showOnlineIndicator,
      isOnline: widget.isOnline,
      backgroundColor: widget.backgroundColor,
      border: widget.border,
      boxShadow: widget.boxShadow,
      onTap: widget.enableTapToChange && !_isLoading
          ? _showImageSourceDialog
          : null,
    );

    // Add camera badge if tap to change is enabled
    if (widget.enableTapToChange && !_isLoading) {
      return Stack(
        children: [
          avatar,
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: widget.radius * 0.6,
              height: widget.radius * 0.6,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.camera_alt,
                size: widget.radius * 0.3,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    return avatar;
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        LinearProgressIndicator(
          value: _uploadProgress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),
        const SizedBox(height: 8),
        Text(
          _loadingStatus,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showChangeButton)
          ElevatedButton.icon(
            onPressed: _showImageSourceDialog,
            icon: const Icon(Icons.camera_alt, size: 18),
            label: Text(widget.changeButtonText ??
                (_currentAvatarUrl?.isNotEmpty == true ? 'Change' : 'Add')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        if (widget.showChangeButton &&
            widget.showRemoveButton &&
            _currentAvatarUrl?.isNotEmpty == true)
          const SizedBox(width: 12),
        if (widget.showRemoveButton && _currentAvatarUrl?.isNotEmpty == true)
          TextButton.icon(
            onPressed: _removeAvatar,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(widget.removeButtonText ?? 'Remove'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red[600],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
      ],
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Choose Avatar Source',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              _buildSourceOption(
                icon: Icons.camera_alt,
                title: 'Take Photo',
                subtitle: 'Use camera to take a new photo',
                onTap: () {
                  Navigator.pop(context);
                  _changeAvatar(ImageSource.camera);
                },
              ),
              const SizedBox(height: 12),
              _buildSourceOption(
                icon: Icons.photo_library,
                title: 'Choose from Gallery',
                subtitle: 'Select an image from your gallery',
                onTap: () {
                  Navigator.pop(context);
                  _changeAvatar(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppTheme.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeAvatar(ImageSource source) async {
    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
      _loadingStatus = 'Preparing...';
    });

    try {
      if (widget.isUserAvatar) {
        final updatedUser = await _avatarService.changeUserAvatar(
          source: source,
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _uploadProgress = progress.progress;
                _loadingStatus = progress.status;
              });
            }
          },
        );

        setState(() {
          _currentAvatarUrl = updatedUser.avatarUrl;
        });

        widget.onUserAvatarChanged?.call(updatedUser);
      } else {
        await _avatarService.changeEntityAvatar(
          entityType: widget.entityType!,
          entityId: widget.entityId!,
          source: source,
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _uploadProgress = progress.progress;
                _loadingStatus = progress.status;
              });
            }
          },
        );

        // For entity avatars, we need to get the new URL from the progress
        // This is a simplification - in a real app, you'd fetch the updated entity
        widget.onEntityAvatarChanged?.call(_currentAvatarUrl ?? '');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avatar updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update avatar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeAvatar() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Avatar'),
        content: const Text('Are you sure you want to remove your avatar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _loadingStatus = 'Removing avatar...';
    });

    try {
      if (widget.isUserAvatar) {
        final updatedUser = await _avatarService.removeUserAvatar();
        setState(() {
          _currentAvatarUrl = null;
        });
        widget.onUserAvatarChanged?.call(updatedUser);
      } else {
        await _avatarService.updateEntityAvatar(
          entityType: widget.entityType!,
          entityId: widget.entityId!,
          avatarUrl: '',
        );
        setState(() {
          _currentAvatarUrl = null;
        });
        widget.onEntityAvatarChanged?.call('');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avatar removed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove avatar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
