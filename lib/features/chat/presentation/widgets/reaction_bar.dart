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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...emojis
                .map((e) => _EmojiButton(emoji: e, onTap: () => onSelect(e))),
            const SizedBox(width: 4),
            IconButton(
              iconSize: 20,
              padding: EdgeInsets.zero,
              onPressed: onOpenPicker,
              icon: const Icon(Icons.add_reaction_outlined),
            )
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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
