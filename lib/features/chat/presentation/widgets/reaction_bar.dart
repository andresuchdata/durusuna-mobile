import 'package:flutter/material.dart';

class ReactionBar extends StatelessWidget {
  final List<String> emojis;
  final void Function(String emoji) onSelect;
  final VoidCallback onOpenPicker;

  const ReactionBar({
    super.key,
    required this.emojis,
    required this.onSelect,
    required this.onOpenPicker,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...emojis
                .map((e) => _EmojiButton(emoji: e, onTap: () => onSelect(e))),
            const SizedBox(width: 2),
            _PlusButton(onTap: onOpenPicker),
          ],
        ),
      ),
    );
  }
}

class _EmojiButton extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;

  const _EmojiButton({required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        margin: const EdgeInsets.symmetric(horizontal: 1),
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

class _PlusButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PlusButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(4),
        child: const Icon(
          Icons.add_rounded,
          size: 18,
          color: Colors.black54,
        ),
      ),
    );
  }
}
