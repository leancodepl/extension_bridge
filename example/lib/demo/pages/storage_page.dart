import 'dart:async';
import 'dart:typed_data';

import 'package:extension_bridge_example/demo/code_view.dart';
import 'package:extension_bridge_example/demo/demo_page.dart';
import 'package:extension_bridge_example/demo/state.dart';
import 'package:extension_bridge_example/main.dart';
import 'package:flutter/material.dart';

/// Everything in the App Group, as Dart sees it.
class const StoragePage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const DemoPage(
      title: 'Shared storage',
      icon: Icons.storage_rounded,
      color: Colors.blueGrey,
      intro:
          'One App Group, read and written by Dart, the widgets, the share '
          'extension and the intents. This page refreshes whenever an '
          'extension changes something.',
      apis: ['bridge.storage.getAll', 'bridge.files.list'],
      live: _Inspector(),
      snippets: [
        Snippet.dart('Dart', '''
const bridge = ExtensionBridge(appGroup: 'group.co.leancode.extensionBridgeExample');

await bridge.storage.set('counter', 42);   // bool, int, double, String, Uint8List
await bridge.storage.setJson('profile', {'name': 'Ada'});
final everything = await bridge.storage.getAll();
final names = await bridge.files.list();'''),
        Snippet.swift('Swift (any extension)', '''
let storage = ExtensionBridgeStorage(appGroup: Demo.appGroup)
let counter = storage.integer(forKey: "counter") ?? 0
let profile = try storage.decode(Profile.self, forKey: "profile") // Codable

let files = ExtensionBridgeFiles(appGroup: Demo.appGroup)
let png = files.read("art/square.png")'''),
      ],
    );
  }
}

class const _Inspector() extends StatefulWidget {
  @override
  State<_Inspector> createState() => _InspectorState();
}

class _InspectorState() extends State<_Inspector> {
  Map<String, Object> _values = const {};
  List<String> _files = const [];
  StreamSubscription<void>? _changes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_changes?.cancel());
    _changes = DemoScope.of(context).changes.listen((_) => _load());
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    final values = await bridge.storage.getAll();
    var files = const <String>[];
    try {
      files = await bridge.files.list();
    } on Exception {
      // Files are not available on the web.
    }
    if (mounted) {
      setState(() {
        _values = values;
        _files = files;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when the demo state changes too.
    DemoScope.of(context);
    final keys = _values.keys.toList()..sort();
    const mono = TextStyle(fontFamily: 'Menlo', fontSize: 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                title: Text('bridge.storage · ${keys.length} keys'),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _load,
                ),
              ),
              for (final key in keys)
                ListTile(
                  dense: true,
                  title: Text(key, style: mono),
                  subtitle: Text(
                    _describe(_values[key]!),
                    style: mono,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(_values[key].runtimeType.toString()),
                ),
            ],
          ),
        ),
        Card(
          child: Column(
            children: [
              ListTile(title: Text('bridge.files · ${_files.length} files')),
              for (final name in _files)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(name, style: mono),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _describe(Object value) => switch (value) {
    Uint8List() => '${value.length} bytes',
    _ => '$value',
  };
}
