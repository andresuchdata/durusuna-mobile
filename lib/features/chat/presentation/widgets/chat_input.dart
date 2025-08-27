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
      debugPrint('⌨️ [CHAT_INPUT] Starting typing indicator');
      widget.onTyping(true);
    }

    // Reset typing timer
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        setState(() => _isTyping = false);
        debugPrint('⌨️ [CHAT_INPUT] Stopping typing indicator (timeout)');
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Chat input row with sleek design
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Main text input container
                Expanded(
                  child: Container(
                    constraints:
                        const BoxConstraints(minHeight: 40, maxHeight: 100),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2C2C2C)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.transparent, width: 0),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Inline emoji button inside the input
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: IconButton(
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
                                  ? Icons.keyboard_outlined
                                  : Icons.sentiment_satisfied_alt_outlined,
                              size: 20,
                            ),
                            color: _showEmojiPicker
                                ? AppTheme.primaryColor
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 28, minHeight: 28),
                          ),
                        ),
                        // Text field
                        Expanded(
                          child: TextField(
                            controller: widget.controller,
                            focusNode: widget.focusNode,
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(
                                fontSize: 16,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 10),
                            ),
                            maxLines: 5,
                            minLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                            onTap: () {
                              if (_showEmojiPicker) {
                                setState(() => _showEmojiPicker = false);
                              }
                            },
                          ),
                        ),

                        // Camera icon inside input (no border)
                        Padding(
                          padding: const EdgeInsets.only(right: 6, bottom: 2),
                          child: IconButton(
                            onPressed: widget.onAttachment,
                            icon: const Icon(
                              Icons.camera_alt_outlined,
                              size: 20,
                            ),
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 28, minHeight: 28),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

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

  // Deprecated: replaced by inline icons within the input row

  Widget _buildSendButton() {
    return Container(
      key: const ValueKey('send'),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: _handleSend,
        icon: const Icon(
          Icons.send_rounded,
          color: Colors.white,
          size: 20,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildVoiceButton() {
    return Container(
      key: const ValueKey('voice'),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: () {
          // TODO: Implement voice recording
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voice recording coming soon')),
          );
        },
        icon: const Icon(
          Icons.mic_rounded,
          color: Colors.white,
          size: 20,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
