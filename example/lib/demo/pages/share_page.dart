import 'dart:async';
import 'dart:typed_data';

import 'package:extension_bridge_example/demo/code_view.dart';
import 'package:extension_bridge_example/demo/demo_page.dart';
import 'package:extension_bridge_example/demo/state.dart';
import 'package:extension_bridge_example/main.dart';
import 'package:flutter/material.dart';

/// Shows what the share extension saved.
class const SharePage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const DemoPage(
      title: 'Share extension',
      icon: Icons.ios_share_rounded,
      color: Colors.teal,
      intro:
          'A native share extension saves photos, links and text into the App '
          'Group with ExtensionBridgeKit. Flutter reads them with the same keys '
          'and file names – and refreshes the moment you tap Done.',
      apis: ['bridge.storage.getJson', 'bridge.files', 'ExtensionBridgeKit'],
      steps: [
        'Open Photos, Safari or Notes and tap Share.',
        'Choose "Extension Bridge" (first time: More → enable it).',
        'Tap Done and come back: the items are below.',
      ],
      live: _Inbox(),
      snippets: [
        Snippet.swift('The extension writes with ExtensionBridgeKit', r'''
let files = ExtensionBridgeFiles(appGroup: Demo.appGroup)
let storage = ExtensionBridgeStorage(appGroup: Demo.appGroup)

let name = "share/\(UUID().uuidString).jpg"
try files.write(jpeg, to: name)

let inbox = (try? storage.decode([InboxItem].self, forKey: "share.inbox")) ?? []
try storage.encode([InboxItem(kind: .image, value: name)] + inbox,
                   forKey: "share.inbox")
Demo.notifyChanged() // a Darwin notification the app listens to'''),
        Snippet.dart('Flutter reads the same keys and files', '''
final inbox = await bridge.storage.getJson('share.inbox') as List;
for (final item in inbox) {
  if (item['kind'] == 'image') {
    final bytes = await bridge.files.read(item['value']);
  }
}'''),
        Snippet.dart('Live updates through a feature event stream', '''
bridge.feature('demo').events<int>('changes').listen((_) => reload());'''),
        Snippet.swift('…backed by a Darwin notification', '''
func listen(to stream: String, arguments: Any?, sink: ExtensionBridgeEventSink)
  throws -> ExtensionBridgeSubscription
{
  let observer = DarwinNotificationObserver(name: Demo.changedNotification) {
    sink.send(Int(Date().timeIntervalSince1970 * 1000))
  }
  return ExtensionBridgeSubscription { observer.cancel() }
}'''),
      ],
      sources: [
        'ios/Share/ShareViewController.swift',
        'ios/Shared/Demo.swift',
        'ios/Runner/DemoFeatures.swift',
      ],
    );
  }
}

class const _Inbox() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = DemoScope.of(context);
    final theme = Theme.of(context);

    if (state.inbox.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.inbox_outlined),
          title: Text('Nothing shared yet'),
          subtitle: Text('Share a photo, link or text to Extension Bridge.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in state.inbox)
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (item.kind == 'image') _SharedImage(name: item.value),
                ListTile(
                  leading: Icon(switch (item.kind) {
                    'image' => Icons.image_outlined,
                    'url' => Icons.link,
                    _ => Icons.notes,
                  }),
                  title: Text(
                    item.value,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${item.kind} · shared at '
                    '${TimeOfDay.fromDateTime(item.sharedAt).format(context)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Clear inbox'),
            onPressed: () => guard(context, () async {
              for (final item in state.inbox) {
                if (item.kind == 'image') {
                  await bridge.files.delete(item.value);
                }
              }
              await bridge.storage.remove(inboxKey);
              await state.reload();
            }),
          ),
        ),
      ],
    );
  }
}

class const _SharedImage({required final String name}) extends StatefulWidget {
  @override
  State<_SharedImage> createState() => _SharedImageState();
}

class _SharedImageState() extends State<_SharedImage> {
  late final Future<Uint8List?> _bytes = bridge.files.read(widget.name);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _bytes,
      builder: (context, snapshot) => switch (snapshot.data) {
        final bytes? => Image.memory(bytes, height: 220, fit: BoxFit.cover),
        null => const SizedBox(height: 220),
      },
    );
  }
}
