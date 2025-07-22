import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/constants/app_theme.dart';
import '../models/user.dart';
import '../services/chat_service.dart';

class GroupProfileCard extends StatefulWidget {
  final Conversation conversation;
  final VoidCallback? onLeaveGroup;
  final VoidCallback? onAddMembers;
  final VoidCallback? onEditGroup;
  final Function(User)? onUserTap;

  const GroupProfileCard({
    super.key,
    required this.conversation,
    this.onLeaveGroup,
    this.onAddMembers,
    this.onEditGroup,
    this.onUserTap,
  });

  @override
  State<GroupProfileCard> createState() => _GroupProfileCardState();
}

class _GroupProfileCardState extends State<GroupProfileCard> {
  @override
  Widget build(BuildContext context) {
    final participants = widget.conversation.participants;
    final memberCount = participants.length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                // Group Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppTheme.primaryColor,
                      backgroundImage:
                          widget.conversation.avatarUrl?.isNotEmpty == true
                              ? NetworkImage(widget.conversation.avatarUrl!)
                              : null,
                      child: widget.conversation.avatarUrl?.isEmpty != false
                          ? const Icon(
                              Icons.group,
                              size: 50,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    if (widget.onEditGroup != null)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: widget.onEditGroup,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // Group Name
                Text(
                  widget.conversation.name ?? 'Group Chat',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                // Group Description
                if (widget.conversation.description?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      widget.conversation.description!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Group Info
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildInfoItem(
                        icon: Icons.people,
                        label: 'Members',
                        value: '$memberCount',
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppTheme.borderColor,
                      ),
                      _buildInfoItem(
                        icon: Icons.calendar_today,
                        label: 'Created',
                        value: _formatDate(widget.conversation.createdAt),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                if (widget.onAddMembers != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.onAddMembers,
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Add Members'),
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
                if (widget.onAddMembers != null && widget.onEditGroup != null)
                  const SizedBox(width: 12),
                if (widget.onEditGroup != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onEditGroup,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit Group'),
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
          ),

          const SizedBox(height: 8),

          // Members Section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Members Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      const Text(
                        'Members',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$memberCount',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Members List
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: participants.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final member = participants[index];
                      return _buildMemberTile(member);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Bottom Actions
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              border: Border(
                top: BorderSide(color: AppTheme.borderColor, width: 1),
              ),
            ),
            child: Column(
              children: [
                // Media & Files Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Show media and files
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Media & Files coming soon')),
                      );
                    },
                    icon: const Icon(Icons.photo_library, size: 18),
                    label: const Text('Media & Files'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Leave Group Button
                if (widget.onLeaveGroup != null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showLeaveGroupDialog(),
                      icon: const Icon(Icons.exit_to_app, size: 18),
                      label: const Text('Leave Group'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: BorderSide(color: AppTheme.errorColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMemberTile(User member) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primaryColor,
            backgroundImage: member.avatarUrl?.isNotEmpty == true
                ? NetworkImage(member.avatarUrl!)
                : null,
            child: member.avatarUrl?.isEmpty != false
                ? Text(
                    '${member.firstName[0]}${member.lastName[0]}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  )
                : null,
          ),
          // Online indicator (for future use when we have real-time presence)
          // Positioned(
          //   bottom: 0,
          //   right: 0,
          //   child: Container(
          //     width: 14,
          //     height: 14,
          //     decoration: BoxDecoration(
          //       color: Colors.green,
          //       shape: BoxShape.circle,
          //       border: Border.all(color: Colors.white, width: 2),
          //     ),
          //   ),
          // ),
        ],
      ),
      title: Text(
        member.displayName,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getUserTypeColor(member.userType).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _getUserTypeLabel(member.userType),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _getUserTypeColor(member.userType),
              ),
            ),
          ),
          if (member.email.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                member.email,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => _handleMemberAction(value, member),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'message',
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline, size: 18),
                const SizedBox(width: 8),
                const Text('Message'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'view_profile',
            child: Row(
              children: [
                const Icon(Icons.person, size: 18),
                const SizedBox(width: 8),
                const Text('View Profile'),
              ],
            ),
          ),
          // Only show admin actions if current user is admin
          // PopupMenuItem(
          //   value: 'remove',
          //   child: Row(
          //     children: [
          //       const Icon(Icons.person_remove, size: 18, color: AppTheme.errorColor),
          //       const SizedBox(width: 8),
          //       const Text('Remove', style: TextStyle(color: AppTheme.errorColor)),
          //     ],
          //   ),
          // ),
        ],
        child: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
      ),
      onTap: widget.onUserTap != null ? () => widget.onUserTap!(member) : null,
    );
  }

  void _handleMemberAction(String action, User member) {
    switch (action) {
      case 'message':
        Navigator.of(context).pop();
        // TODO: Start direct chat with member
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Starting chat with ${member.displayName}')),
        );
        break;
      case 'view_profile':
        Navigator.of(context).pop();
        // TODO: Show member profile
        if (widget.onUserTap != null) {
          widget.onUserTap!(member);
        }
        break;
      case 'remove':
        Navigator.of(context).pop();
        _showRemoveMemberDialog(member);
        break;
    }
  }

  void _showLeaveGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: Text(
          'Are you sure you want to leave "${widget.conversation.name ?? 'this group'}"? You won\'t be able to see new messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Close profile card
              widget.onLeaveGroup?.call();
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _showRemoveMemberDialog(User member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove ${member.displayName} from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Remove member from group
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else {
      return timeago.format(date);
    }
  }

  String _getUserTypeLabel(UserType userType) {
    switch (userType) {
      case UserType.teacher:
        return 'Teacher';
      case UserType.student:
        return 'Student';
      case UserType.parent:
        return 'Parent';
    }
  }

  Color _getUserTypeColor(UserType userType) {
    switch (userType) {
      case UserType.teacher:
        return AppTheme.primaryColor;
      case UserType.student:
        return AppTheme.successColor;
      case UserType.parent:
        return AppTheme.warningColor;
    }
  }

  /// Show group profile card as a modal bottom sheet
  static Future<void> show(
    BuildContext context, {
    required Conversation conversation,
    VoidCallback? onLeaveGroup,
    VoidCallback? onAddMembers,
    VoidCallback? onEditGroup,
    Function(User)? onUserTap,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GroupProfileCard(
        conversation: conversation,
        onLeaveGroup: onLeaveGroup,
        onAddMembers: onAddMembers,
        onEditGroup: onEditGroup,
        onUserTap: onUserTap,
      ),
    );
  }
}
