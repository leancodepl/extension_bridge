import 'package:extension_bridge/extension_bridge.dart';
import 'package:extension_bridge_example/demo/demo_page.dart';
import 'package:extension_bridge_example/demo/pages/art_page.dart';
import 'package:extension_bridge_example/demo/pages/chart_page.dart';
import 'package:extension_bridge_example/demo/pages/controls_page.dart';
import 'package:extension_bridge_example/demo/pages/intents_page.dart';
import 'package:extension_bridge_example/demo/pages/links_page.dart';
import 'package:extension_bridge_example/demo/pages/live_activity_page.dart';
import 'package:extension_bridge_example/demo/pages/share_page.dart';
import 'package:extension_bridge_example/demo/pages/storage_page.dart';
import 'package:extension_bridge_example/demo/pages/widgets_page.dart';
import 'package:extension_bridge_example/demo/state.dart';
import 'package:flutter/material.dart';

/// One demo on the home page.
@immutable
final class const Demo({
  required final String title,
  required final String subtitle,
  required final IconData icon,
  required final Color color,
  required final WidgetBuilder builder,

  /// The host of the extension links that open this demo, for example
  /// `counter` for `extensionbridge://counter`.
  final String? linkHost,
});

/// Every demo, in the order they are shown.
final demos = [
  Demo(
    title: 'Home screen widgets',
    subtitle: 'Interactive counter · Lock Screen · StandBy',
    icon: Icons.widgets_rounded,
    color: Colors.indigo,
    builder: (_) => const WidgetsPage(),
    linkHost: 'counter',
  ),
  Demo(
    title: 'Flutter-painted widget',
    subtitle: 'Render a PNG in Flutter, show it in WidgetKit',
    icon: Icons.palette_rounded,
    color: Colors.purple,
    builder: (_) => const ArtPage(),
    linkHost: 'art',
  ),
  Demo(
    title: 'SwiftUI chart widget',
    subtitle: 'Flutter sends JSON, Swift Charts draws it',
    icon: Icons.bar_chart_rounded,
    color: Colors.deepOrange,
    builder: (_) => const ChartPage(),
    linkHost: 'chart',
  ),
  Demo(
    title: 'Live Activities',
    subtitle: 'Lock Screen & Dynamic Island, driven by Dart',
    icon: Icons.timelapse_rounded,
    color: Colors.orange.shade800,
    builder: (_) => const LiveActivityPage(),
    linkHost: 'order',
  ),
  Demo(
    title: 'Share extension',
    subtitle: 'Share photos, links and text into Flutter',
    icon: Icons.ios_share_rounded,
    color: Colors.teal,
    builder: (_) => const SharePage(),
  ),
  Demo(
    title: 'App Intents & Siri',
    subtitle: 'Shortcuts, Spotlight, Siri, Action button',
    icon: Icons.mic_rounded,
    color: Colors.blue.shade700,
    builder: (_) => const IntentsPage(),
  ),
  Demo(
    title: 'Control Center',
    subtitle: 'iOS 18 controls: button, toggle, open app',
    icon: Icons.toggle_on_rounded,
    color: Colors.pink,
    builder: (_) => const ControlsPage(),
    linkHost: 'controls',
  ),
  Demo(
    title: 'Deep links',
    subtitle: 'Every ExtensionLink that opened the app',
    icon: Icons.link_rounded,
    color: Colors.green.shade700,
    builder: (_) => const LinksPage(),
  ),
  Demo(
    title: 'Shared storage inspector',
    subtitle: 'The App Group as Dart sees it, live',
    icon: Icons.storage_rounded,
    color: Colors.blueGrey,
    builder: (_) => const StoragePage(),
  ),
];

/// The demo app: a catalog of everything `extension_bridge` can do.
class const DemoApp({super.key}) extends StatefulWidget {
  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState() extends State<DemoApp> {
  final _state = DemoState();
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _state
      ..onLink = _open
      ..start();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  /// Opens the demo an extension link points to.
  void _open(ExtensionLink link) {
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Opened by ${link.source ?? 'a link'}: ${link.uri}'),
        ),
      );
    final demo = demos.where((it) => it.linkHost == link.uri.host).firstOrNull;
    final navigator = _navigator.currentState;
    if (demo == null || navigator == null) {
      return;
    }
    navigator
      ..popUntil((route) => route.isFirst)
      ..push(MaterialPageRoute<void>(builder: demo.builder));
  }

  @override
  Widget build(BuildContext context) {
    return DemoScope(
      notifier: _state,
      child: ListenableBuilder(
        listenable: _state,
        builder: (context, _) {
          final seed = _state.partyMode ? Colors.pink : Colors.indigo;
          return MaterialApp(
            title: 'extension_bridge',
            debugShowCheckedModeBanner: false,
            navigatorKey: _navigator,
            scaffoldMessengerKey: _messenger,
            theme: ThemeData(colorSchemeSeed: seed),
            darkTheme: ThemeData(
              colorSchemeSeed: seed,
              brightness: Brightness.dark,
            ),
            home: const HomePage(),
          );
        },
      ),
    );
  }
}

/// Lists the demos under a live header.
class const HomePage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = DemoScope.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              state.partyMode ? 'extension_bridge 🎉' : 'extension_bridge',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
            sliver: SliverList.list(
              children: [
                const _Hero(),
                const SectionTitle('Demos'),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final (index, demo) in demos.indexed) ...[
                        if (index > 0) const Divider(height: 1, indent: 72),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          leading: DemoIcon(icon: demo.icon, color: demo.color),
                          title: Text(
                            demo.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(demo.subtitle),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: demo.builder),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SectionTitle('Event log'),
                if (state.log.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Links that open the app and changes made by extensions '
                      'show up here.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (final entry in state.log.take(8))
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.bolt_rounded),
                            title: Text(entry.title),
                            subtitle: Text(
                              entry.detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              TimeOfDay.fromDateTime(entry.at).format(context),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class const _Hero() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = DemoScope.of(context);
    final colors = state.partyMode
        ? [Colors.pink, Colors.orange]
        : [const Color(0xFF3F51B5), const Color(0xFF03A9F4)];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'One bridge between Flutter and native app extensions.',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Storage, files, deep links, background Dart and your own '
              'native features – shared by the app and every extension.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SHARED COUNTER',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Text(
                        '${state.counter}',
                        key: ValueKey(state.counter),
                        style: const TextStyle(
                          fontSize: 48,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton.filledTonal(
                  onPressed: () => state.add(-1),
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: colors.first,
                  ),
                  onPressed: () => state.add(1),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (state.updatedBy case final by?)
              Text(
                'Last changed by $by',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
