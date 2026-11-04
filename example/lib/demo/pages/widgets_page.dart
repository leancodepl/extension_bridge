import 'dart:async';

import 'package:extension_bridge_example/demo/code_view.dart';
import 'package:extension_bridge_example/demo/demo_page.dart';
import 'package:extension_bridge_example/demo/state.dart';
import 'package:extension_bridge_example/main.dart';
import 'package:flutter/material.dart';

/// The interactive counter widget.
class const WidgetsPage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const DemoPage(
      title: 'Home screen widgets',
      icon: Icons.widgets_rounded,
      color: Colors.indigo,
      intro:
          'A WidgetKit widget reads the counter Dart saved in the App Group. Its '
          '+ and − buttons run Dart in a background isolate – even when the app '
          'is closed.',
      apis: [
        'bridge.storage',
        'registerBackgroundCallback',
        'ExtensionBridgeBackground',
        'ExtensionBridgeLinks',
      ],
      steps: [
        'Long-press the Home Screen → Edit → Add Widget → "Extension Bridge".',
        'Pick "Shared counter" (small or medium).',
        'Tap + on the widget: Dart increments it in the background.',
        'Lock Screen: long-press it → Customize → add the counter there too.',
        'Tap the widget itself to open this page through an ExtensionLink.',
      ],
      live: _CounterPanel(),
      snippets: [
        Snippet.dart(
          'Write from Flutter, then reload the widget',
          '''
await bridge.storage.set('counter', counter);
await bridge.feature('widgets').invoke('reload', {'kind': 'CounterWidget'});''',
        ),
        Snippet.swift(
          'Read it in the widget extension (ExtensionBridgeKit)',
          '''
let storage = ExtensionBridgeStorage(appGroup: Demo.appGroup)
let entry = CounterEntry(
  date: .now,
  counter: storage.integer(forKey: "counter") ?? 0,
  updatedBy: storage.string(forKey: "counter.updatedBy"))
completion(Timeline(entries: [entry], policy: .never))''',
        ),
        Snippet.swift('An interactive button that runs Dart', '''
Button(intent: IncrementCounterIntent(amount: 1)) {
  Image(systemName: "plus")
}

// Shared by the app and the widget extension. LiveActivityIntent makes
// iOS perform it in the app process, where Flutter lives.
struct IncrementCounterIntent: LiveActivityIntent {
  @Parameter(title: "Amount", default: 1) var amount: Int

  func perform() async throws -> some IntentResult {
    try await ExtensionBridgeBackground.dispatch(
      "increment", arguments: ["amount": amount])
    WidgetCenter.shared.reloadAllTimelines()
    return .result()
  }
}'''),
        Snippet.dart('…which lands in a background isolate', '''
@pragma('vm:entry-point')
Future<Object?> onBackgroundEvent(BackgroundEvent event) async {
  switch (event.name) {
    case 'increment':
      final args = event.arguments! as Map;
      return addToCounter(args['amount'] as int,
          updatedBy: 'Dart in a background isolate');
  }
  return null;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ExtensionBridge.registerBackgroundCallback(onBackgroundEvent);
  runApp(const ExampleApp());
}'''),
        Snippet.swift(
          'Tapping the widget opens the app with a link',
          '''
.widgetURL(ExtensionBridgeLinks.url("extensionbridge://counter", source: "widget"))''',
        ),
        Snippet.dart('A feature: your own native code, no channels', '''
final widgets = bridge.feature('widgets');
final installed = await widgets.invokeList<Map>('installed');'''),
        Snippet.swift('…registered once in AppDelegate', r'''
ExtensionBridgePlugin.register(feature: WidgetsFeature())

final class WidgetsFeature: ExtensionBridgeFeature {
  let name = "widgets"
  func handle(_ call: ExtensionBridgeCall) async throws -> Any? {
    switch call.method {
    case "installed":
      return try await WidgetCenter.shared.currentConfigurations()
        .map { ["kind": $0.kind, "family": "\($0.family)"] }
    ...'''),
      ],
      sources: [
        'ios/Widgets/CounterWidget.swift',
        'ios/Shared/Intents.swift',
        'ios/Runner/DemoFeatures.swift',
        'lib/main.dart',
      ],
    );
  }
}

class const _CounterPanel() extends StatefulWidget {
  @override
  State<_CounterPanel> createState() => _CounterPanelState();
}

class _CounterPanelState() extends State<_CounterPanel> {
  List<Map<Object?, Object?>> _installed = const [];
  StreamSubscription<void>? _changes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_changes?.cancel());
    _changes = DemoScope.of(context).changes.listen((_) => _loadInstalled());
    unawaited(_loadInstalled());
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  Future<void> _loadInstalled() async {
    if (!isIOS) {
      return;
    }
    final installed = await widgets.invokeList<Map<Object?, Object?>>(
      'installed',
    );
    if (mounted) {
      setState(() => _installed = installed ?? const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = DemoScope.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${state.counter}',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton.filledTonal(
                      onPressed: () => state.add(-1),
                      icon: const Icon(Icons.remove),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () => state.add(1),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                Text(
                  state.updatedBy == null
                      ? 'Not changed yet'
                      : 'Last changed by ${state.updatedBy}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.memory_rounded),
                      label: const Text('+1 in a background isolate'),
                      onPressed: () => guard(context, () async {
                        final counter = await example.invoke<int>(
                          'dispatchBackground',
                          {'name': 'increment'},
                        );
                        await state.reload();
                        if (context.mounted) {
                          toast(context, 'Background Dart returned $counter');
                        }
                      }),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Reset'),
                      onPressed: () => state.add(-state.counter),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (isIOS)
          Card(
            child: ListTile(
              leading: const Icon(Icons.dashboard_customize_outlined),
              title: Text(
                _installed.isEmpty
                    ? 'No widgets installed yet'
                    : '${_installed.length} widget(s) installed',
              ),
              subtitle: _installed.isEmpty
                  ? const Text('From WidgetCenter.currentConfigurations()')
                  : Text(
                      _installed
                          .map((it) => '${it['kind']} · ${it['family']}')
                          .join('\n'),
                    ),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadInstalled,
              ),
            ),
          ),
      ],
    );
  }
}
