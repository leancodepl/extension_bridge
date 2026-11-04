import 'dart:async';

import 'package:extension_bridge/extension_bridge.dart';
import 'package:extension_bridge_example/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Whether the extension demos can run: they are iOS only for now.
final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

// Storage keys shared with Swift (`Demo.Key` in `ios/Shared/Demo.swift`).

/// Whether party mode is on.
const partyModeKey = 'partyMode';

/// The caption of the Flutter-painted widget.
const artCaptionKey = 'art.caption';

/// What the share extension saved.
const inboxKey = 'share.inbox';

/// Something that happened, shown in the event log.
@immutable
final class const LogEntry({
  required final String title,
  required final String detail,
  required final DateTime at,
});

/// One item saved by the share extension.
@immutable
final class const InboxItem({
  required final String id,
  required final String kind,
  required final String value,
  required final DateTime sharedAt,
}) {
  /// Reads an `InboxItem` encoded by Swift's `JSONEncoder`.
  factory fromJson(Map<Object?, Object?> json) => InboxItem(
    id: json['id']! as String,
    kind: json['kind']! as String,
    value: json['value']! as String,
    sharedAt: DateTime.fromMillisecondsSinceEpoch(json['sharedAt']! as int),
  );
}

/// Everything the demo shows, kept in sync with the extensions.
///
/// Reloads when the app resumes and whenever an extension posts the `changes`
/// event of `bridge.feature('demo')`.
class DemoState() extends ChangeNotifier with WidgetsBindingObserver {
  /// The shared counter.
  int counter = 0;

  /// Who changed [counter] last.
  String? updatedBy;

  /// When [counter] changed last.
  DateTime? updatedAt;

  /// Whether the Control Center toggle turned party mode on.
  bool partyMode = false;

  /// What the share extension saved, newest first.
  List<InboxItem> inbox = const [];

  /// The extension links that opened the app, newest first.
  final links = <(ExtensionLink, DateTime)>[];

  /// What happened, newest first.
  final log = <LogEntry>[];

  /// Called with every extension link, to navigate to its page.
  void Function(ExtensionLink link)? onLink;

  /// Called when an extension changed shared state.
  final _changes = StreamController<void>.broadcast();

  /// Fires when an extension changed shared state.
  Stream<void> get changes => _changes.stream;

  final _subscriptions = <StreamSubscription<Object?>>[];

  /// Starts listening to links, extensions and the app lifecycle.
  void start() {
    WidgetsBinding.instance.addObserver(this);
    unawaited(reload());
    if (kIsWeb) {
      return;
    }
    _subscriptions.add(ExtensionBridge.links.listen(_receive));
    unawaited(
      ExtensionBridge.initialLink.then((link) {
        if (link != null) {
          _receive(link);
        }
      }),
    );
    if (isIOS) {
      _subscriptions.add(
        demo.events<int>('changes').listen((_) {
          _addLog('Extension changed shared state', 'Darwin notification');
          unawaited(reload());
          _changes.add(null);
        }),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_changes.close());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(reload());
      _changes.add(null);
    }
  }

  void _receive(ExtensionLink link) {
    links.insert(0, (link, DateTime.now()));
    _addLog('Opened by ${link.source ?? 'a link'}', link.uri.toString());
    onLink?.call(link);
  }

  void _addLog(String title, String detail) {
    log.insert(0, LogEntry(title: title, detail: detail, at: DateTime.now()));
    if (log.length > 50) {
      log.removeLast();
    }
    notifyListeners();
  }

  /// Reads everything again from shared storage.
  Future<void> reload() async {
    final storage = bridge.storage;
    counter = await storage.get<int>(counterKey) ?? 0;
    updatedBy = await storage.get<String>(counterUpdatedByKey);
    final at = await storage.get<int>(counterUpdatedAtKey);
    updatedAt = at == null ? null : DateTime.fromMillisecondsSinceEpoch(at);
    partyMode = await storage.get<bool>(partyModeKey) ?? false;
    final json = await storage.getJson(inboxKey);
    inbox = json is List
        ? [for (final item in json) InboxItem.fromJson(item as Map)]
        : const [];
    notifyListeners();
  }

  /// Changes the counter from the app itself.
  Future<void> add(int amount) async {
    await addToCounter(amount, updatedBy: 'Dart in the app');
    await reloadWidgets();
    await reload();
  }

  /// Turns party mode on or off and updates the Control Center toggle.
  Future<void> setPartyMode({required bool enabled}) async {
    await bridge.storage.set(partyModeKey, enabled);
    await reloadWidgets();
    await reload();
  }

  /// Logs a message from a demo page.
  void report(String title, String detail) => _addLog(title, detail);
}

/// Reloads widgets and controls; a no-op where there are none.
Future<void> reloadWidgets([String? kind]) async {
  if (isIOS) {
    await widgets.invoke<void>('reload', {'kind': ?kind});
  } else if (!kIsWeb) {
    try {
      await example.invoke<void>('reloadWidgets');
    } on ExtensionBridgeException {
      // Not every platform has widgets.
    }
  }
}

/// Provides the [DemoState] to the widget tree.
class const DemoScope({
  super.key,
  required DemoState super.notifier,
  required super.child,
}) extends InheritedNotifier<DemoState> {
  /// The nearest [DemoState], rebuilding [context] when it changes.
  static DemoState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DemoScope>()!.notifier!;
}
