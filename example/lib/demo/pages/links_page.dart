import 'package:extension_bridge_example/demo/code_view.dart';
import 'package:extension_bridge_example/demo/demo_page.dart';
import 'package:extension_bridge_example/demo/state.dart';
import 'package:extension_bridge_example/main.dart';
import 'package:flutter/material.dart';

/// Every extension link that opened the app.
class const LinksPage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Deep links',
      icon: Icons.link_rounded,
      color: Colors.green.shade700,
      intro:
          'Widgets, Live Activities, controls and intents open the app with a '
          'URL marked by the extension_bridge query parameter. Only marked URLs '
          'are handled, so links meant for go_router or OAuth are left alone.',
      apis: const [
        'ExtensionBridge.links',
        'ExtensionBridge.initialLink',
        'ExtensionBridgeLinks.url',
      ],
      steps: const [
        'Tap the counter widget, the Live Activity or the "Open" control.',
        'The app opens on the matching page and the link shows up below.',
      ],
      live: const _LinkList(),
      snippets: const [
        Snippet.swift('Mark a URL in any extension', '''
ExtensionBridgeLinks.url("extensionbridge://counter", source: "widget")
// extensionbridge://counter?extension_bridge=widget'''),
        Snippet.dart('Receive it in Dart', r'''
final initial = await ExtensionBridge.initialLink; // cold start
ExtensionBridge.links.listen((link) {
  print('${link.source} opened ${link.uri}'); // widget opened extensionbridge://counter
});'''),
      ],
    );
  }
}

class const _LinkList() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = DemoScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: state.links.isEmpty
              ? const ListTile(
                  leading: Icon(Icons.link_off),
                  title: Text('No links yet'),
                )
              : Column(
                  children: [
                    for (final (link, at) in state.links)
                      ListTile(
                        leading: const Icon(Icons.link),
                        title: Text(link.uri.toString()),
                        subtitle: Text(
                          'source: ${link.source ?? '–'} · '
                          '${TimeOfDay.fromDateTime(at).format(context)}',
                        ),
                      ),
                  ],
                ),
        ),
        if (isIOS)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Deliver a test link natively'),
              onPressed: () => guard(
                context,
                () => example.invoke<void>('openLink', {
                  'uri': 'extensionbridge://links?from=swift',
                  'source': 'demo_button',
                }),
              ),
            ),
          ),
      ],
    );
  }
}
