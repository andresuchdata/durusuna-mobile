import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/services/chat_service.dart';
import '../../../../shared/models/user.dart';
import '../widgets/contact_tile.dart';
import 'chat_page.dart';

class ContactsPage extends ConsumerStatefulWidget {
  const ContactsPage({super.key});

  @override
  ConsumerState<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends ConsumerState<ContactsPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSearching = false;
  String _searchQuery = '';

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

  void _startChat(User user) async {
    try {
      // Clear any currently viewed conversation before starting chat
      ref.read(currentConversationProvider.notifier).state = null;
      print(
          '📱 ContactsPage: Cleared current conversation before starting chat');

      // First check if conversation already exists
      await ref.read(conversationsProvider.notifier).loadConversations();
      final conversations = ref.read(conversationsProvider).conversations;

      // Look for existing conversation with this user
      final existingConversation = conversations
          .cast<Conversation?>()
          .firstWhere(
            (conv) =>
                conv != null && conv.participants.any((p) => p.id == user.id),
            orElse: () => null,
          );

      final Conversation conversation;
      if (existingConversation != null) {
        // Use existing conversation
        conversation = existingConversation;
      } else {
        // Create a new conversation object for new chat
        // The actual backend conversation will be created when first message is sent
        print(
            '📞 ContactsPage - Creating new conversation for user: ${user.id}');
        final conversationId = 'new_${user.id}';
        print('📞 ContactsPage - Generated conversation ID: $conversationId');

        conversation = Conversation(
          id: conversationId, // Special ID format for new conversations
          type: 'direct',
          participants: [user],
          otherUser: user,
          unreadCount: 0,
          lastActivity: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isOnline: false,
        );
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ChatPage(conversation: conversation),
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open conversation: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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
            : const Text('Select Contact'),
        elevation: 0,
        backgroundColor: Colors.transparent,
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
          // Contact type filter
          if (!_isSearching) _buildContactTypeFilter(),

          // Contacts list
          Expanded(
            child: _buildContactsList(contactsState),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTypeFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterChip(
              label: 'All',
              isSelected: true, // TODO: Implement filter state
              onTap: () {
                // TODO: Filter by all users
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterChip(
              label: 'Teachers',
              isSelected: false,
              onTap: () {
                // TODO: Filter by teachers
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterChip(
              label: 'Students',
              isSelected: false,
              onTap: () {
                // TODO: Filter by students
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterChip(
              label: 'Parents',
              isSelected: false,
              onTap: () {
                // TODO: Filter by parents
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
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
          return ContactTile(
            user: contact,
            onTap: () => _startChat(contact),
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
