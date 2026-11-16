import 'dart:async';
import 'dart:math';

import 'package:extension_bridge/extension_bridge.dart';
import 'package:extension_bridge_example/demo/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The App Group shared with the app extensions.
///
/// On iOS it has to be added to the App Groups capability of the app and of
/// every extension. Other platforms use it as a namespace.
const appGroup = 'group.co.leancode.extensionBridgeExample';

/// The bridge used by the app, its extensions and its background callback.
const bridge = ExtensionBridge(appGroup: appGroup);

/// The native feature registered by the example in `MainActivity.kt`,
/// `AppDelegate.swift` (iOS) and `AppDelegate.swift` (macOS).
final example = bridge.feature('example');

/// Reloads WidgetKit timelines and Control Center controls (iOS).
final widgets = bridge.feature('widgets');

/// Starts, updates and ends the order Live Activity (iOS).
final liveActivity = bridge.feature('liveActivity');

/// Streams `changes` whenever an extension changes shared state (iOS).
final demo = bridge.feature('demo');

/// The key of the counter shown by the app and its home screen widget.
const counterKey = 'counter';

/// Who changed the counter last, shown by the widget.
const counterUpdatedByKey = 'counter.updatedBy';

/// When the counter changed last, in milliseconds since the epoch.
const counterUpdatedAtKey = 'counter.updatedAt';

/// Handles events native code dispatches while the app may be closed: widget
/// and Live Activity buttons, Control Center controls, Siri and Shortcuts.
@pragma('vm:entry-point')
Future<Object?> onBackgroundEvent(BackgroundEvent event) async {
  final arguments = event.arguments is Map
      ? (event.arguments! as Map).cast<String, Object?>()
      : const <String, Object?>{};

  switch (event.name) {
    case 'increment':
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await demo.invoke<void>('trace', {
          'event': 'increment $arguments (isolate $_isolateId)',
        });
      }
      final counter = await addToCounter(
        arguments['amount'] as int? ?? 1,
        updatedBy: 'Dart in a background isolate',
      );
      await example.invoke<void>('reloadWidgets');
      return counter;
    case 'advanceOrder':
      return await advanceOrder(arguments['id']! as String);
    case 'ask':
      return await answer(arguments['question'] as String? ?? '');
    case 'echo':
      return event.arguments;
    default:
      throw UnsupportedError('Unknown background event ${event.name}');
  }
}

/// Identifies the isolate in debug traces.
final _isolateId = Random().nextInt(1 << 16);

/// The last pending counter update of this isolate.
Future<void> _counterUpdates = Future.value();

/// Adds [amount] to the shared counter and returns the new value.
///
/// Updates of one isolate run one after another, so two quick taps never
/// read the same value and lose an increment.
Future<int> addToCounter(int amount, {required String updatedBy}) {
  final update = _counterUpdates.then(
    (_) => _addToCounter(amount, updatedBy: updatedBy),
  );
  _counterUpdates = update.then<void>((_) {}, onError: (_) {});
  return update;
}

Future<int> _addToCounter(int amount, {required String updatedBy}) async {
  final counter = (await bridge.storage.get<int>(counterKey) ?? 0) + amount;
  await bridge.storage.set(counterKey, counter);
  await bridge.storage.set(counterUpdatedByKey, updatedBy);
  await bridge.storage.set(
    counterUpdatedAtKey,
    DateTime.now().millisecondsSinceEpoch,
  );
  return counter;
}

/// The steps of an order, matching `OrderAttributes.steps` in Swift.
const orderSteps = ['Ordered', 'Preparing', 'On the way', 'Delivered'];

/// Minutes until delivery at each step.
const _etaMinutes = [12, 9, 4, 0];

/// The arguments of the `start` and `update` calls for [step], computed in
/// Dart so the Live Activity shows what Dart decided.
Map<String, Object> orderState(int step, {String? item}) => {
  'step': step,
  'eta': DateTime.now()
      .add(Duration(minutes: _etaMinutes[step]))
      .millisecondsSinceEpoch,
  'message': switch (step) {
    0 => 'Dart received your order',
    1 => 'Dart is preheating the oven',
    2 => 'A rider picked it up, says Dart',
    _ => 'Delivered! Enjoy 🎉',
  },
};

/// Moves the Live Activity [id] to its next step and returns that step.
///
/// Runs in the app when you tap "Next step" and in a background isolate when
/// you tap ⏩ on the Lock Screen or in the Dynamic Island.
Future<int> advanceOrder(String id) async {
  final activities = await liveActivity.invokeList<Map<Object?, Object?>>(
    'list',
  );
  final current = activities?.firstWhere(
    (it) => it['id'] == id,
    orElse: () => const {},
  );
  final step = min((current?['step'] as int? ?? 0) + 1, orderSteps.length - 1);
  final delivered = step == orderSteps.length - 1;
  await liveActivity.invoke<void>('update', {
    'id': id,
    ...orderState(step),
    if (delivered) 'alert': 'Delivered! Enjoy 🎉',
  });
  if (delivered) {
    await liveActivity.invoke<void>('end', {'id': id});
  }
  return step;
}

const _fortunes = [
  'Hot reload is a lifestyle.',
  'There is a widget for that.',
  'Everything is a widget, even this answer.',
  'Your code will compile on the first try. Today only.',
  'One bridge, every extension.',
  'Const constructors bring good luck.',
];

/// Answers the "Ask Flutter" App Intent.
Future<String> answer(String question) async {
  final counter = await bridge.storage.get<int>(counterKey) ?? 0;
  final fortune = _fortunes[Random().nextInt(_fortunes.length)];
  final asked = question.trim().isEmpty
      ? ''
      : 'You asked “${question.trim()}”. ';
  return '$asked$fortune The counter is $counter. '
      '(Answered by Dart in the background.)';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (await ExtensionBridge.isBackgroundExecutionSupported) {
    await ExtensionBridge.registerBackgroundCallback(onBackgroundEvent);
  }
  runApp(const ExampleApp());
}

/// The example app.
class const ExampleApp({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const DemoApp();
  }
}
