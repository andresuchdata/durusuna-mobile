import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';

class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onSend;
  final Function(bool) onTyping;
  final VoidCallback onAttachment;

  const ChatInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onTyping,
    required this.onAttachment,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  bool _isTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    
    if (hasText && !_isTyping) {
      setState(() => _isTyping = true);
      widget.onTyping(true);
    }
    
    // Reset typing timer
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        setState(() => _isTyping = false);
        widget.onTyping(false);
      }
    });
  }

  void _handleSend() {
    final text = widget.controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSend(text);
      
      // Stop typing indicator
      if (_isTyping) {
        setState(() => _isTyping = false);
        widget.onTyping(false);
        _typingTimer?.cancel();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Attachment button
            IconButton(
              onPressed: widget.onAttachment,
              icon: const Icon(Icons.attach_file),
              color: AppTheme.primaryColor,
            ),
            
            // Text input
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 100),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        onSubmitted: (_) => _handleSend(),
                      ),
                    ),
                    
                    // Emoji button
                    IconButton(
                      onPressed: () {
                        // TODO: Implement emoji picker
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Emoji picker coming soon')),
                        );
                      },
                      icon: const Icon(Icons.emoji_emotions_outlined),
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Send/Voice button
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: widget.controller.text.trim().isNotEmpty
                  ? _buildSendButton()
                  : _buildVoiceButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return Container(
      key: const ValueKey('send'),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: _handleSend,
        icon: const Icon(
          Icons.send,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildVoiceButton() {
    return Container(
      key: const ValueKey('voice'),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: () {
          // TODO: Implement voice recording
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voice recording coming soon')),
          );
        },
        icon: const Icon(
          Icons.mic,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
} 