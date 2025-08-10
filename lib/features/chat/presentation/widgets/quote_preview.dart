import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/helpers/link_text.dart';

class QuotePreview extends StatelessWidget {
  final bool isMe;
  final bool isGroup;
  final Color leftColor;
  final String text;
  final String? quotedName;

  const QuotePreview({
    super.key,
    required this.isMe,
    required this.isGroup,
    required this.leftColor,
    required this.text,
    this.quotedName,
  });

  @override
  Widget build(BuildContext context) {
    final baseTextStyle = TextStyle(
      fontSize: 13,
      color: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkTextPrimary
          : AppTheme.textPrimary,
      height: 1.25,
    );

    final nameStyle = baseTextStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: quotedName != null && isGroup
          ? leftColor
          : (Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkTextSecondary
              : AppTheme.textSecondary),
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(2, 2, 2, 2),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(alpha: 0.9)
            : AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: leftColor, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if ((quotedName?.isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(quotedName!, style: nameStyle),
            ),
          LinkTextHelper.buildLinkifiedText(
            context,
            text,
            baseTextStyle,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
