import 'package:extension_bridge_example/demo/code_view.dart';
import 'package:extension_bridge_example/demo/demo_page.dart';
import 'package:extension_bridge_example/demo/state.dart';
import 'package:extension_bridge_example/main.dart';
import 'package:flutter/material.dart';

/// App Intents: Siri, Shortcuts, Spotlight and the Action button.
class const IntentsPage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'App Intents & Siri',
      icon: Icons.mic_rounded,
      color: Colors.blue.shade700,
      intro:
          'App Shortcuts are available right after install – in Siri, '
          'Spotlight, the Shortcuts app and on the Action button. They run Dart '
          'in a background isolate and get its return value back.',
      apis: const [
        'ExtensionBridgeBackground.dispatch',
        'ExtensionBridgePlugin.deliverLink',
        'bridge.storage',
      ],
      steps: const [
        'Say "Hey Siri, ask Extension Bridge".',
        'Or search "Extension Bridge" in Spotlight and run an action.',
        'Or open Shortcuts → App Shortcuts → Extension Bridge.',
        'Action button: Settings → Action Button → Shortcut → Extension Bridge.',
      ],
      live: const _ShortcutsPanel(),
      snippets: const [
        Snippet.swift('An intent that asks Dart', r'''
struct AskFlutterIntent: AppIntent {
  static let title: LocalizedStringResource = "Ask Flutter"

  @Parameter(title: "Question", default: "How are you?")
  var question: String

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let answer = try await ExtensionBridgeBackground.dispatch(
      "ask", arguments: ["question": question]) as? String ?? "…"
    return .result(dialog: "\(answer)")
  }
}'''),
        Snippet.dart('Dart answers, without the app on screen', r'''
@pragma('vm:entry-point')
Future<Object?> onBackgroundEvent(BackgroundEvent event) async {
  switch (event.name) {
    case 'ask':
      final counter = await bridge.storage.get<int>('counter') ?? 0;
      return '$fortune The counter is $counter.';
  }
  return null;
}'''),
        Snippet.swift('Open the app on a page', '''
struct OpenCounterIntent: AppIntent {
  static let openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    ExtensionBridgePlugin.deliverLink(
      URL(string: "extensionbridge://counter")!, source: "app_intent")
    return .result()
  }
}'''),
        Snippet.swift('Siri phrases with zero setup', r'''
struct DemoShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: AskFlutterIntent(),
      phrases: ["Ask Flutter in \(.applicationName)", "Ask \(.applicationName)"],
      shortTitle: "Ask Flutter",
      systemImageName: "bubble.left.and.text.bubble.right")
    ...
  }
}'''),
      ],
      sources: const [
        'ios/Runner/AppIntents.swift',
        'ios/Shared/Intents.swift',
        'lib/main.dart',
      ],
    );
  }
}

const _shortcuts = [
  (
    Icons.add_circle_outline,
    'Increment',
    '“Increment the counter in Extension Bridge”',
    'Dart in the background, returns the new value',
  ),
  (
    Icons.numbers,
    'Get counter',
    '“What is the counter in Extension Bridge”',
    'Swift reads bridge.storage directly',
  ),
  (
    Icons.chat_bubble_outline,
    'Ask Flutter',
    '“Ask Extension Bridge”',
    'Dart computes the answer Siri speaks',
  ),
  (
    Icons.open_in_new,
    'Open counter',
    '“Open the counter in Extension Bridge”',
    'Opens the app, Dart gets an ExtensionLink',
  ),
];

class const _ShortcutsPanel() extends StatefulWidget {
  @override
  State<_ShortcutsPanel> createState() => _ShortcutsPanelState();
}

class _ShortcutsPanelState() extends State<_ShortcutsPanel> {
  String? _answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Column(
            children: [
              for (final (icon, title, phrase, how) in _shortcuts)
                ListTile(
                  leading: Icon(icon),
                  title: Text(title),
                  subtitle: Text('$phrase\n$how'),
                  isThreeLine: true,
                ),
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Run "Ask Flutter" from here',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Dispatches the same background event Siri does – it runs '
                  'in a separate, headless isolate.',
                ),
                if (_answer case final answer?) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(answer),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Ask Flutter'),
                      onPressed: () => guard(context, () async {
                        final answer = await example.invoke<String>(
                          'dispatchBackground',
                          {
                            'name': 'ask',
                            'arguments': {'question': 'Who are you?'},
                          },
                        );
                        setState(() => _answer = answer);
                      }),
                    ),
                    if (isIOS)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open Shortcuts'),
                        onPressed: () => guard(
                          context,
                          () => demo.invoke<void>('open', {
                            'url': 'shortcuts://',
                          }),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
