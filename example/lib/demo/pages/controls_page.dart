import 'package:extension_bridge_example/demo/code_view.dart';
import 'package:extension_bridge_example/demo/demo_page.dart';
import 'package:extension_bridge_example/demo/state.dart';
import 'package:flutter/material.dart';

/// iOS 18 Control Center controls.
class const ControlsPage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const DemoPage(
      title: 'Control Center',
      icon: Icons.toggle_on_rounded,
      color: Colors.pink,
      intro:
          'Three iOS 18 controls from the same widget extension: a button that '
          'runs Dart, a toggle backed by shared storage that re-themes this app '
          'live, and a button that opens the app with an ExtensionLink.',
      apis: [
        'ExtensionBridgeStorage',
        'ExtensionBridgeBackground',
        'ExtensionBridgeLinks',
        "bridge.feature('demo').events",
      ],
      steps: [
        'Open Control Center → tap + → Add a Control.',
        'Search "Extension Bridge" and add the three controls.',
        'Flip "Party mode" over this app: it re-themes instantly.',
        'They also work on the Lock Screen and the Action button.',
      ],
      live: _PartyPanel(),
      snippets: [
        Snippet.swift('A toggle backed by shared storage', r'''
struct PartyModeControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: "PartyModeControl", provider: Value()) { isOn in
      ControlWidgetToggle("Party mode", isOn: isOn, action: SetPartyModeIntent()) {
        Label($0 ? "On" : "Off", systemImage: "party.popper.fill")
      }
    }
  }

  struct Value: ControlValueProvider {
    var previewValue: Bool { true }
    func currentValue() async throws -> Bool {
      ExtensionBridgeStorage(appGroup: Demo.appGroup).bool(forKey: "partyMode") ?? false
    }
  }
}

struct SetPartyModeIntent: SetValueIntent {
  @Parameter(title: "Party mode") var value: Bool

  func perform() async throws -> some IntentResult {
    Demo.storage.set(value, forKey: "partyMode")
    Demo.notifyChanged() // → bridge.feature('demo').events('changes')
    return .result()
  }
}'''),
        Snippet.dart('Flutter flips it too, and Control Center follows', '''
await bridge.storage.set('partyMode', enabled);
await bridge.feature('widgets').invoke('reload'); // reloads controls too'''),
        Snippet.swift('A button that runs Dart', r'''
ControlWidgetButton(action: IncrementCounterIntent(amount: 1)) {
  Label("Counter: \(counter)", systemImage: "plus.circle.fill")
}'''),
        Snippet.swift('A button that opens the app', '''
ControlWidgetButton(action: OpenURLIntent(
  ExtensionBridgeLinks.url(URL(string: "extensionbridge://controls")!,
                          source: "control"))) {
  Label("Open demo", systemImage: "arrow.up.forward.app.fill")
}'''),
      ],
      sources: ['ios/Widgets/Controls.swift', 'ios/Shared/Intents.swift'],
    );
  }
}

class const _PartyPanel() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = DemoScope.of(context);
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: Text(
              state.partyMode ? '🎉' : '😴',
              style: const TextStyle(fontSize: 28),
            ),
            title: const Text('Party mode'),
            subtitle: const Text('Stored in bridge.storage["partyMode"]'),
            value: state.partyMode,
            onChanged: (enabled) =>
                guard(context, () => state.setPartyMode(enabled: enabled)),
          ),
          ListTile(
            leading: const Icon(Icons.exposure_plus_1),
            title: Text('Counter: ${state.counter}'),
            subtitle: Text(state.updatedBy ?? 'Not changed yet'),
          ),
        ],
      ),
    );
  }
}
