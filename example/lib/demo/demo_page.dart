import 'dart:async';

import 'package:extension_bridge_example/demo/code_view.dart';
import 'package:extension_bridge_example/demo/state.dart';
import 'package:flutter/material.dart';

/// The layout every demo page shares: what it is, how to try it, a live
/// panel, and the code that makes it work.
class const DemoPage({
  super.key,
  required final String title,
  required final IconData icon,
  required final Color color,
  required final String intro,
  required final List<String> apis,
  final List<String> steps = const [],
  final Widget? live,
  final List<Snippet> snippets = const [],
  final List<String> sources = const [],
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(title),
            backgroundColor: Color.alphaBlend(
              color.withValues(alpha: 0.08),
              theme.colorScheme.surface,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
            sliver: SliverList.list(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DemoIcon(icon: icon, color: color, size: 52),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(intro, style: theme.textTheme.bodyLarge),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final api in apis) ApiChip(api)],
                ),
                if (!isIOS) ...[
                  const SizedBox(height: 16),
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.phone_iphone),
                      title: Text('iOS only for now'),
                      subtitle: Text('Run the example on an iPhone to try it.'),
                    ),
                  ),
                ],
                if (steps.isNotEmpty) ...[
                  const SectionTitle('Try it'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          for (final (index, step) in steps.indexed)
                            ListTile(
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: color.withValues(alpha: 0.15),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              title: Text(step),
                              dense: true,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (live case final live?) ...[
                  const SectionTitle('Live'),
                  live,
                ],
                if (snippets.isNotEmpty) ...[
                  const SectionTitle('How it works'),
                  for (final snippet in snippets) ...[
                    CodeView(snippet: snippet),
                    const SizedBox(height: 12),
                  ],
                ],
                if (sources.isNotEmpty) ...[
                  const SectionTitle('Full source'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final source in sources)
                        ActionChip(
                          avatar: const Icon(Icons.description_outlined),
                          label: Text(source.split('/').last),
                          onPressed: () =>
                              unawaited(showSource(context, source)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A rounded, tinted icon.
class const DemoIcon({
  super.key,
  required final IconData icon,
  required final Color color,
  final double size = 44,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.white, 0.3)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.52),
    );
  }
}

/// Names an `extension_bridge` API used by a demo.
class const ApiChip(final String api, {super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        api,
        style: TextStyle(
          fontFamily: 'Menlo',
          fontSize: 11.5,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// A section heading.
class const SectionTitle(final String title, {super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 28, 4, 10),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Runs [action], reporting bridge errors in a snack bar.
Future<void> guard(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } on Exception catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

/// Shows [message] in a snack bar.
void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
