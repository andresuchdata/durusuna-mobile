import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/services/chat_service.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/models/message.dart';
import '../widgets/contact_tile.dart';

class ForwardContactsPage extends ConsumerStatefulWidget {
  final List<Message> messagesToForward;

  const ForwardContactsPage({
    super.key,
    required this.messagesToForward,
  });

  @override
  ConsumerState<ForwardContactsPage> createState() =>
      _ForwardContactsPageState();
}

class _ForwardContactsPageState extends ConsumerState<ForwardContactsPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _selectedContactIds = {};
  bool _isSearching = false;
  String _searchQuery = '';
  bool _isForwarding = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Load initial contacts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contactsProvider.notifier).loadContacts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final state = ref.read(contactsProvider);
      if (!state.isLoadingMore && state.hasMore) {
        ref.read(contactsProvider.notifier).loadContacts(loadMore: true);
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });

    if (query.trim().isEmpty) {
      ref.read(contactsProvider.notifier).loadContacts();
    } else {
      ref.read(contactsProvider.notifier).searchContacts(query);
    }
  }

  void _startSearch() {
    setState(() => _isSearching = true);
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
    ref.read(contactsProvider.notifier).loadContacts();
  }

  void _toggleContactSelection(User contact) {
    setState(() {
      if (_selectedContactIds.contains(contact.id)) {
        _selectedContactIds.remove(contact.id);
      } else {
        if (_selectedContactIds.length < 3) {
          _selectedContactIds.add(contact.id);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can only forward to up to 3 contacts'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
      }
    });
  }

  Future<void> _forwardMessages() async {
    if (_selectedContactIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one contact'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() => _isForwarding = true);

    try {
      final contactsState = ref.read(contactsProvider);
      final selectedContacts = contactsState.contacts
          .where((c) => _selectedContactIds.contains(c.id))
          .toList();

      final chatService = ref.read(chatServiceProvider);

      // Forward messages to each selected contact
      for (final contact in selectedContacts) {
        for (final message in widget.messagesToForward) {
          await chatService.sendMessage(
            receiverId: contact.id,
            content: message.content,
            messageType: message.messageType,
            metadata: message.messageType != MessageType.text
                ? message.metadata
                : null,
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Messages forwarded to ${selectedContacts.length} contact${selectedContacts.length > 1 ? 's' : ''}',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isForwarding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to forward messages: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsState = ref.watch(contactsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search contacts...',
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Forward to...',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  if (_selectedContactIds.isNotEmpty)
                    Text(
                      '${_selectedContactIds.length}/3 selected',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _stopSearch,
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _startSearch,
            ),
        ],
      ),
      body: Column(
        children: [
          // Selected contacts preview
          if (_selectedContactIds.isNotEmpty) _buildSelectedContactsPreview(),

          // Message preview
          _buildMessagePreview(),

          // Contacts list
          Expanded(
            child: _buildContactsList(contactsState),
          ),
        ],
      ),
      bottomNavigationBar: _selectedContactIds.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.borderColor)),
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isForwarding ? null : _forwardMessages,
                    icon: _isForwarding
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(_isForwarding ? 'Forwarding...' : 'Forward'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSelectedContactsPreview() {
    final contactsState = ref.watch(contactsProvider);
    final selectedContacts = contactsState.contacts
        .where((c) => _selectedContactIds.contains(c.id))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Forward to:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedContacts.map((contact) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      contact.displayName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _toggleContactSelection(contact),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagePreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.forward,
                  size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Forwarding ${widget.messagesToForward.length} message${widget.messagesToForward.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.messagesToForward.take(3).map((message) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    message.displayContent,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            ),
          ),
          if (widget.messagesToForward.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'and ${widget.messagesToForward.length - 3} more...',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContactsList(ContactsState state) {
    if (state.isLoading && state.contacts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.contacts.isEmpty) {
      return _buildErrorState(state.error!);
    }

    if (state.contacts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (_searchQuery.isEmpty) {
          ref.read(contactsProvider.notifier).loadContacts();
        } else {
          ref.read(contactsProvider.notifier).searchContacts(_searchQuery);
        }
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: state.contacts.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.contacts.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final contact = state.contacts[index];
          final isSelected = _selectedContactIds.contains(contact.id);

          return ContactTile(
            user: contact,
            isSelected: isSelected,
            onTap: () => _toggleContactSelection(contact),
            trailing: isSelected
                ? const Icon(
                    Icons.check_circle,
                    color: AppTheme.primaryColor,
                  )
                : const Icon(
                    Icons.radio_button_unchecked,
                    color: AppTheme.textTertiary,
                  ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty ? Icons.search_off : Icons.people_outline,
            size: 64,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No contacts found'
                : 'No contacts available',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'There are no other users in your school yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textTertiary,
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _stopSearch,
              icon: const Icon(Icons.clear),
              label: const Text('Clear Search'),
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
            size: 64,
            color: AppTheme.errorColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ref.read(contactsProvider.notifier).loadContacts(),
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
