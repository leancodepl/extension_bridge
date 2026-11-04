import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:extension_bridge_example/demo/code_view.dart';
import 'package:extension_bridge_example/demo/demo_page.dart';
import 'package:extension_bridge_example/demo/state.dart';
import 'package:extension_bridge_example/main.dart';
import 'package:flutter/material.dart';

/// The storage key of the chart data, `Demo.Key.chart` in Swift.
const chartKey = 'chart';

/// Flutter sends data; SwiftUI and Swift Charts draw it.
class const ChartPage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const DemoPage(
      title: 'SwiftUI chart widget',
      icon: Icons.bar_chart_rounded,
      color: Colors.deepOrange,
      intro:
          'The opposite of the Flutter-painted widget: Flutter only sends data '
          'as JSON, and the widget draws it natively with SwiftUI and Swift '
          'Charts – crisp at every size, in light and dark mode.',
      apis: ['bridge.storage.setJson', 'ExtensionBridgeStorage.decode'],
      steps: [
        'Add the "SwiftUI chart" widget (small, medium, large or Lock Screen).',
        'Drag the bars below, pick a style and a color.',
        'Tap "Send to widget" and look at your Home Screen.',
      ],
      live: _ChartEditor(),
      snippets: [
        Snippet.dart('Send plain data from Dart', '''
await bridge.storage.setJson('chart', {
  'title': 'Hot reloads',
  'unit': 'reloads',
  'accent': '#E91E63',
  'style': 'bar', // bar, line or area
  'points': [
    {'label': 'Mon', 'value': 12},
    {'label': 'Tue', 'value': 30},
  ],
  'updatedAt': DateTime.now().millisecondsSinceEpoch,
});
await bridge.feature('widgets').invoke('reload', {'kind': 'ChartWidget'});'''),
        Snippet.swift('Decode it as Codable in the widget', '''
struct ChartData: Codable {
  struct Point: Codable { var label: String; var value: Double }
  var title: String
  var unit: String
  var accent: String
  var style: String
  var points: [Point]
}

let storage = ExtensionBridgeStorage(appGroup: Demo.appGroup)
let data = try? storage.decode(ChartData.self, forKey: "chart")'''),
        Snippet.swift('Draw it with Swift Charts', '''
Chart(data.points) { point in
  BarMark(x: .value("Label", point.label),
          y: .value(data.unit, point.value))
    .foregroundStyle(data.color)
    .cornerRadius(4)
}'''),
      ],
      sources: ['ios/Widgets/ChartWidget.swift'],
    );
  }
}

/// A ready-made dataset.
typedef _Preset = ({
  String title,
  String unit,
  Color color,
  List<double> values,
});

const _labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const _presets = <_Preset>[
  (
    title: 'Hot reloads',
    unit: 'reloads',
    color: Color(0xFFE91E63),
    values: [12, 30, 22, 41, 35, 8, 15],
  ),
  (
    title: 'Coffee',
    unit: 'cups',
    color: Color(0xFF8D6E63),
    values: [3, 4, 2, 5, 4, 1, 1],
  ),
  (
    title: 'Bugs fixed',
    unit: 'bugs',
    color: Color(0xFF43A047),
    values: [5, 9, 14, 7, 11, 2, 0],
  ),
  (
    title: 'Steps',
    unit: 'thousand steps',
    color: Color(0xFF1E88E5),
    values: [6, 8, 11, 7, 9, 14, 12],
  ),
];

const _accents = [
  Color(0xFFE91E63),
  Color(0xFFFF6F00),
  Color(0xFF43A047),
  Color(0xFF1E88E5),
  Color(0xFF8E24AA),
  Color(0xFF8D6E63),
];

class const _ChartEditor() extends StatefulWidget {
  @override
  State<_ChartEditor> createState() => _ChartEditorState();
}

class _ChartEditorState() extends State<_ChartEditor> {
  var _preset = _presets.first;
  late var _values = [..._preset.values];
  late var _color = _preset.color;
  var _style = 'bar';
  var _sending = false;

  /// The value of a full height bar.
  late var _max = _preset.values.reduce(max) * 1.6;

  String get _hex =>
      '#${(_color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  Map<String, Object> get _json => {
    'title': _preset.title,
    'unit': _preset.unit,
    'accent': _hex,
    'style': _style,
    'points': [
      for (final (index, label) in _labels.indexed)
        {'label': label, 'value': _values[index].roundToDouble()},
    ],
  };

  void _choose(_Preset preset) => setState(() {
    _preset = preset;
    _values = [...preset.values];
    _color = preset.color;
    _max = preset.values.reduce(max) * 1.6;
  });

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await bridge.storage.setJson(chartKey, {
        ..._json,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      await reloadWidgets('ChartWidget');
      if (mounted) {
        DemoScope.of(context)
            .report('Sent chart data', '${_preset.title} · $_style · $_hex');
        toast(context, 'Sent! Check the "SwiftUI chart" widget.');
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _values.fold<double>(0, (sum, it) => sum + it.round());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                    for (final preset in _presets)
                      ChoiceChip(
                        label: Text(preset.title),
                        selected: preset == _preset,
                        onSelected: (_) => _choose(preset),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${total.round()} ${_preset.unit}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: _color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Drag a bar to change it',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                SizedBox(height: 180, child: _bars(theme)),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'bar',
                      label: Text('Bars'),
                      icon: Icon(Icons.bar_chart),
                    ),
                    ButtonSegment(
                      value: 'line',
                      label: Text('Line'),
                      icon: Icon(Icons.show_chart),
                    ),
                    ButtonSegment(
                      value: 'area',
                      label: Text('Area'),
                      icon: Icon(Icons.area_chart),
                    ),
                  ],
                  selected: {_style},
                  onSelectionChanged: (it) => setState(() => _style = it.first),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  children: [
                    for (final color in _accents)
                      GestureDetector(
                        onTap: () => setState(() => _color = color),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: color,
                          child: color == _color
                              ? const Icon(
                                  Icons.check,
                                  size: 18,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Randomize',
                      icon: const Icon(Icons.casino_outlined),
                      onPressed: () => setState(() {
                        final random = Random();
                        _values = [
                          for (final _ in _labels)
                            (random.nextDouble() * _max).roundToDouble(),
                        ];
                      }),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _sending || !isIOS ? null : _send,
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Send to widget'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        CodeView(
          snippet: Snippet(
            title: "bridge.storage.setJson('chart', …)",
            language: 'JSON',
            code: const JsonEncoder.withIndent('  ').convert(_json),
          ),
        ),
      ],
    );
  }

  Widget _bars(ThemeData theme) => LayoutBuilder(
    builder: (context, constraints) {
      final height = constraints.maxHeight - 44;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (index, label) in _labels.indexed)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) => setState(() {
                  final value =
                      _values[index] - details.delta.dy / height * _max;
                  _values[index] = value.clamp(0, _max);
                }),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${_values[index].round()}',
                      style: theme.textTheme.labelSmall,
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 80),
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      height: max(4, _values[index] / _max * height),
                      decoration: BoxDecoration(
                        color: _color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(label, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
