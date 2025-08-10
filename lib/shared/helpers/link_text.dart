import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Utilities to render linkified text inside chat bubbles
class LinkTextHelper {
  // Insert zero-width spaces after common URL delimiters to allow soft wrapping
  static String wrapLinksForBreaking(String input) {
    if (input.isEmpty) return input;
    const breakChars = ['/', '?', '&', '=', '.', '-', '_', ':'];
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final ch = input[i];
      buffer.write(ch);
      if (breakChars.contains(ch)) {
        buffer.write('\u200B'); // zero-width space for wrapping
      }
    }
    return buffer.toString();
  }

  /// Build linkified rich text for message/quote content.
  /// Supports http/https/www and bare domains (e.g., google.com, ade.edu.id).
  static Widget buildLinkifiedText(
    BuildContext context,
    String text,
    TextStyle baseStyle, {
    int? maxLines,
    TextOverflow overflow = TextOverflow.fade,
  }) {
    final linkRegExp = RegExp(
      r'((?:https?:\/\/|www\.)[^\s]+|(?<!@)\b(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?:\/[^\s]*)?)',
      caseSensitive: false,
    );

    final spans = <InlineSpan>[];
    int currentIndex = 0;
    final matches = linkRegExp.allMatches(text).toList();

    for (final match in matches) {
      if (match.start > currentIndex) {
        final nonLink = text.substring(currentIndex, match.start);
        spans.add(
            TextSpan(text: wrapLinksForBreaking(nonLink), style: baseStyle));
      }

      final raw = text.substring(match.start, match.end);
      // Separate trailing punctuation to preserve it outside the link
      final trailingMatch = RegExp(r'[\.,!?\)\]]+$').firstMatch(raw);
      final trailing =
          trailingMatch != null ? raw.substring(trailingMatch.start) : '';
      final urlText = trailing.isNotEmpty
          ? raw.substring(0, raw.length - trailing.length)
          : raw;
      final display = wrapLinksForBreaking(urlText);
      final uri =
          Uri.parse(urlText.startsWith('http') ? urlText : 'https://$urlText');
      final linkStyle = baseStyle.copyWith(
        color: const Color.fromARGB(255, 37, 77, 189),
        decoration: TextDecoration.none,
        fontWeight: FontWeight.w600,
      );
      spans.add(TextSpan(
        text: display,
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            try {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {}
          },
      ));
      if (trailing.isNotEmpty) {
        spans.add(TextSpan(text: trailing, style: baseStyle));
      }

      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: wrapLinksForBreaking(text.substring(currentIndex)),
        style: baseStyle,
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      softWrap: true,
      maxLines: maxLines,
      overflow: maxLines != null ? overflow : TextOverflow.visible,
    );
  }
}
