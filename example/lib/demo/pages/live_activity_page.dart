import 'dart:async';

import 'package:extension_bridge_example/demo/code_view.dart';
import 'package:extension_bridge_example/demo/demo_page.dart';
import 'package:extension_bridge_example/demo/state.dart';
import 'package:extension_bridge_example/main.dart';
import 'package:flutter/material.dart';

/// Starts and drives the order Live Activity from Dart.
class const LiveActivityPage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Live Activities',
      icon: Icons.timelapse_rounded,
      color: Colors.orange.shade800,
      intro:
          'ActivityKit lives in a native feature; every state – the step, the '
          'ETA, the message – is computed in Dart. The ⏩ button on the Lock '
          'Screen runs Dart in a background isolate.',
      apis: const [
        "bridge.feature('liveActivity')",
        'ExtensionBridgeBackground',
        'ExtensionBridgeLinks',
      ],
      steps: const [
        'Pick something to order and tap "Start".',
        'Lock the phone, or swipe home to see the Dynamic Island.',
        'Tap ⏩ on the Lock Screen or the expanded Dynamic Island.',
        'Dart advances the order without opening the app.',
        'Tap the Live Activity to come back here through an ExtensionLink.',
      ],
      live: const _OrderPanel(),
      snippets: const [
        Snippet.dart('Start it from Dart', '''
final id = await bridge.feature('liveActivity').invoke<String>('start', {
  'item': 'Flutter pizza',
  'emoji': '🍕',
  ...orderState(0), // step, eta and message, computed in Dart
});'''),
        Snippet.swift('The feature behind it', '''
final class LiveActivityFeature: ExtensionBridgeFeature {
  let name = "liveActivity"

  func handle(_ call: ExtensionBridgeCall) async throws -> Any? {
    switch call.method {
    case "start":
      let attributes = OrderAttributes(
        item: try call.requireArgument("item"),
        emoji: try call.requireArgument("emoji"))
      let activity = try Activity.request(
        attributes: attributes, content: try content(of: call), pushType: nil)
      return activity.id
    case "update": ...
    case "end": ...
    case "list": ...
    default:
      throw ExtensionBridgeError.notImplemented(call)
    }
  }
}'''),
        Snippet.swift('A Lock Screen button that runs Dart', '''
Button(intent: AdvanceOrderIntent(activityID: context.activityID)) {
  Image(systemName: "forward.fill")
}

struct AdvanceOrderIntent: LiveActivityIntent {
  @Parameter(title: "Activity ID") var activityID: String

  func perform() async throws -> some IntentResult {
    try await ExtensionBridgeBackground.dispatch(
      "advanceOrder", arguments: ["id": activityID])
    return .result()
  }
}'''),
        Snippet.dart('Dart decides what happens next', '''
Future<int> advanceOrder(String id) async {
  final activities = await liveActivity.invokeList<Map>('list');
  final current = activities!.firstWhere((it) => it['id'] == id);
  final step = min((current['step'] as int) + 1, orderSteps.length - 1);
  await liveActivity.invoke('update', {'id': id, ...orderState(step)});
  if (step == orderSteps.length - 1) {
    await liveActivity.invoke('end', {'id': id});
  }
  return step;
}'''),
      ],
      sources: const [
        'ios/Widgets/OrderLiveActivity.swift',
        'ios/Shared/OrderAttributes.swift',
        'ios/Runner/DemoFeatures.swift',
        'lib/main.dart',
      ],
    );
  }
}

const _menu = [
  ('🍕', 'Flutter pizza'),
  ('🍔', 'Dart burger'),
  ('🌮', 'Widget tacos'),
  ('☕️', 'Hot reload coffee'),
];

class const _OrderPanel() extends StatefulWidget {
  @override
  State<_OrderPanel> createState() => _OrderPanelState();
}

class _OrderPanelState() extends State<_OrderPanel> {
  var _choice = _menu.first;
  bool? _enabled;
  List<Map<Object?, Object?>> _activities = const [];
  StreamSubscription<void>? _changes;
  Timer? _ticker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_changes?.cancel());
    _changes = DemoScope.of(context).changes.listen((_) => _load());
    unawaited(_load());
    // Keeps the countdowns moving.
    _ticker ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!isIOS) {
      return;
    }
    final enabled = await liveActivity.invoke<bool>('isEnabled');
    final activities = await liveActivity.invokeList<Map<Object?, Object?>>(
      'list',
    );
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _activities = activities ?? const [];
      });
    }
  }

  Future<void> _start() => guard(context, () async {
    final (emoji, item) = _choice;
    final id = await liveActivity.invoke<String>('start', {
      'item': item,
      'emoji': emoji,
      ...orderState(0),
    });
    if (mounted) {
      DemoScope.of(context).report('Started a Live Activity', '$emoji $id');
    }
    await _load();
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = _activities.where((it) => it['state'] == 'active').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_enabled == false)
          const Card(
            child: ListTile(
              leading: Icon(Icons.block),
              title: Text('Live Activities are turned off'),
              subtitle: Text('Settings → Extension Bridge → Live Activities'),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final option in _menu)
                      ChoiceChip(
                        label: Text('${option.$1} ${option.$2}'),
                        selected: option == _choice,
                        onSelected: (_) => setState(() => _choice = option),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: isIOS ? _start : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start'),
                    ),
                    OutlinedButton.icon(
                      onPressed: active.isEmpty
                          ? null
                          : () => guard(context, () async {
                              await liveActivity.invoke<void>('end');
                              await _load();
                            }),
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('End all'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        for (final activity in active)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        activity['emoji']! as String,
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity['item']! as String,
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(activity['message']! as String),
                          ],
                        ),
                      ),
                      Text(
                        _eta(activity['eta']! as int),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Steps(step: activity['step']! as int),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () => guard(context, () async {
                      await advanceOrder(activity['id']! as String);
                      await _load();
                    }),
                    icon: const Icon(Icons.fast_forward_rounded),
                    label: const Text('Next step (Dart in the app)'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _eta(int eta) {
    final left = DateTime.fromMillisecondsSinceEpoch(eta)
        .difference(DateTime.now());
    if (left.isNegative) {
      return '0:00';
    }
    final seconds = (left.inSeconds % 60).toString().padLeft(2, '0');
    return '${left.inMinutes}:$seconds';
  }
}

class const _Steps({required final int step}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final (index, title) in orderSteps.indexed)
          Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: index <= step
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: index == step ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
