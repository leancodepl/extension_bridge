import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A code snippet shown on a demo page.
@immutable
final class const Snippet({
  required final String title,
  required final String language,
  required final String code,
}) {
  /// A Dart snippet.
  const new dart(String title, String code)
    : this(title: title, language: 'Dart', code: code);

  /// A Swift snippet.
  const new swift(String title, String code)
    : this(title: title, language: 'Swift', code: code);
}

const _background = Color(0xFF16161E);
const _foreground = Color(0xFFC0CAF5);
const _comment = Color(0xFF7A82A8);
const _keyword = Color(0xFFBB9AF7);
const _string = Color(0xFF9ECE6A);
const _number = Color(0xFFFF9E64);
const _type = Color(0xFF7DCFFF);
const _annotation = Color(0xFFE0AF68);

const _keywords = {
  // Shared
  'import', 'class', 'final', 'const', 'var', 'let', 'func', 'return', 'if',
  'else', 'switch', 'case', 'default', 'for', 'in', 'while', 'try', 'await',
  'async', 'throw', 'throws', 'static', 'struct', 'enum', 'extension', 'true',
  'false', 'null', 'nil', 'self', 'this', 'super', 'guard', 'some', 'void',
  'override', 'required', 'private', 'public', 'init', 'catch', 'do', 'is',
  'as', 'new', 'get', 'set', 'where', 'protocol', 'typealias', 'late',
  'Future', 'Stream', 'with', 'extends', 'implements', 'break', 'continue',
};

final _token = RegExp(
  r'''(?<comment>//[^\n]*)'''
  r'''|(?<string>"(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*')'''
  r'''|(?<annotation>[@#][A-Za-z_]\w*)'''
  r'''|(?<number>\b\d+(?:\.\d+)?\b)'''
  r'''|(?<word>\b[A-Za-z_]\w*\b)''',
);

/// A small, dependency free syntax highlighter for Dart and Swift.
TextSpan highlight(String code, TextStyle base) {
  final spans = <TextSpan>[];
  var position = 0;
  for (final match in _token.allMatches(code)) {
    if (match.start > position) {
      spans.add(TextSpan(text: code.substring(position, match.start)));
    }
    final text = match[0]!;
    final color = switch (match) {
      _ when match.namedGroup('comment') != null => _comment,
      _ when match.namedGroup('string') != null => _string,
      _ when match.namedGroup('annotation') != null => _annotation,
      _ when match.namedGroup('number') != null => _number,
      _ when _keywords.contains(text) => _keyword,
      _ when text[0].toUpperCase() == text[0] && text[0] != '_' => _type,
      _ => null,
    };
    spans.add(
      TextSpan(
        text: text,
        style: color == null
            ? null
            : TextStyle(
                color: color,
                fontStyle: color == _comment ? FontStyle.italic : null,
              ),
      ),
    );
    position = match.end;
  }
  spans.add(TextSpan(text: code.substring(position)));
  return TextSpan(style: base, children: spans);
}

/// Shows [snippet] with syntax highlighting and a copy button.
class const CodeView({super.key, required final Snippet snippet})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final language = snippet.language;

    return Container(
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.white.withValues(alpha: 0.04),
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
            child: Row(
              children: [
                _LanguageBadge(language: language),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    snippet.title,
                    style: const TextStyle(
                      color: _foreground,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  color: _comment,
                  onPressed: () {
                    unawaited(
                      Clipboard.setData(ClipboardData(text: snippet.code)),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied “${snippet.title}”')),
                    );
                  },
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(14),
            child: SelectableText.rich(
              highlight(
                snippet.code.trim(),
                const TextStyle(
                  fontFamily: 'Menlo',
                  fontFamilyFallback: ['Courier', 'monospace'],
                  fontSize: 12.5,
                  height: 1.45,
                  color: _foreground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class const _LanguageBadge({required final String language})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = language == 'Swift'
        ? const Color(0xFFF05138)
        : const Color(0xFF0175C2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        language,
        style: TextStyle(
          color: Color.lerp(color, Colors.white, 0.35),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Shows a whole source file, bundled as an asset, in a bottom sheet.
Future<void> showSource(BuildContext context, String asset) async {
  final code = await rootBundle.loadString(asset);
  if (!context.mounted) {
    return;
  }
  final name = asset.split('/').last;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: _background,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _comment,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          CodeView(
            snippet: Snippet(
              title: asset.replaceFirst('ios/', 'example/ios/'),
              language: name.endsWith('.swift') ? 'Swift' : 'Dart',
              code: code,
            ),
          ),
        ],
      ),
    ),
  );
}
