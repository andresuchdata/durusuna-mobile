import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import 'emoji_picker.dart';

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
  bool _showEmojiPicker = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onFocusChanged() {
    if (widget.focusNode.hasFocus && _showEmojiPicker) {
      setState(() {
        _showEmojiPicker = false;
      });
    }
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

  void _insertEmoji(String emoji) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    // Handle invalid selection values (common on iOS)
    int start = selection.start;
    int end = selection.end;

    // If selection is invalid, append to end of text
    if (start < 0 || end < 0 || start > text.length || end > text.length) {
      start = text.length;
      end = text.length;
    }

    // Ensure start <= end
    if (start > end) {
      final temp = start;
      start = end;
      end = temp;
    }

    final newText = text.replaceRange(start, end, emoji);
    final newCursorPosition = start + emoji.length;

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: newCursorPosition.clamp(0, newText.length),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Chat input row
        Container(
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
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Row(
                      children: [
                        // Text field
                        Expanded(
                          child: TextField(
                            controller: widget.controller,
                            focusNode: widget.focusNode,
                            decoration: const InputDecoration(
                              hintText: 'Type a message...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            maxLines: 4,
                            minLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                            onTap: () {
                              // Hide emoji picker when text field is tapped
                              if (_showEmojiPicker) {
                                setState(() {
                                  _showEmojiPicker = false;
                                });
                              }
                            },
                          ),
                        ),

                        // Emoji button
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showEmojiPicker = !_showEmojiPicker;
                            });
                            if (_showEmojiPicker) {
                              widget.focusNode.unfocus();
                            } else {
                              widget.focusNode.requestFocus();
                            }
                          },
                          icon: Icon(
                            _showEmojiPicker
                                ? Icons.keyboard
                                : Icons.emoji_emotions_outlined,
                          ),
                          color: _showEmojiPicker
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondary,
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
        ),

        // Emoji picker
        if (_showEmojiPicker)
          EmojiPicker(
            onEmojiSelected: _insertEmoji,
            height: 280,
          ),
      ],
    );
  }

  Widget _buildSendButton() {
    return Container(
      key: const ValueKey('send'),
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
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
      decoration: const BoxDecoration(
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
