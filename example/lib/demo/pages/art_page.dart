import 'dart:async';

import 'package:extension_bridge_example/demo/art.dart';
import 'package:extension_bridge_example/demo/code_view.dart';
import 'package:extension_bridge_example/demo/demo_page.dart';
import 'package:extension_bridge_example/demo/state.dart';
import 'package:extension_bridge_example/main.dart';
import 'package:flutter/material.dart';

/// Flutter paints an image that a WidgetKit widget shows.
class const ArtPage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const DemoPage(
      title: 'Flutter-painted widget',
      icon: Icons.palette_rounded,
      color: Colors.purple,
      intro:
          'Widgets cannot run Flutter, but they can show what Flutter drew. '
          'The app paints a canvas into PNGs and drops them into the App Group; '
          'the widget just displays the file.',
      apis: ['bridge.files', 'bridge.storage', 'ExtensionBridgeFiles'],
      steps: [
        'Add the "Flutter art" widget (small, medium or large).',
        'Pick a palette, an emoji and a caption below.',
        'Tap "Send to widget" and go to the Home Screen.',
      ],
      live: _ArtEditor(),
      snippets: [
        Snippet.dart('Paint with a Canvas, export a PNG', '''
final recorder = ui.PictureRecorder();
ArtPainter(style).paint(Canvas(recorder), size);
final image = await recorder.endRecording()
    .toImage(size.width.round(), size.height.round());
final png = await image.toByteData(format: ui.ImageByteFormat.png);'''),
        Snippet.dart('Share it with the extension', '''
await bridge.files.write('art/square.png', square); // atomic
await bridge.files.write('art/wide.png', wide);
await bridge.storage.set('art.caption', caption);
await bridge.feature('widgets').invoke('reload', {'kind': 'ArtWidget'});'''),
        Snippet.swift('Show it in WidgetKit', '''
let files = ExtensionBridgeFiles(appGroup: Demo.appGroup)
let image = files.read("art/square.png").flatMap(UIImage.init(data:))

Image(uiImage: image).resizable().scaledToFill()'''),
      ],
      sources: ['ios/Widgets/ArtWidget.swift', 'lib/demo/art.dart'],
    );
  }
}

const _emojis = ['🚀', '🦄', '🍕', '🌈', '🐦', '🎧', '🔥', '💙'];

class const _ArtEditor() extends StatefulWidget {
  @override
  State<_ArtEditor> createState() => _ArtEditorState();
}

class _ArtEditorState() extends State<_ArtEditor> {
  var _palette = palettes.keys.first;
  var _emoji = _emojis.first;
  var _seed = 1;
  var _sending = false;
  final _caption = TextEditingController(text: 'Hello from Flutter');

  ArtStyle get _style => ArtStyle(
    colors: palettes[_palette]!,
    emoji: _emoji,
    caption: _caption.text,
    seed: _seed,
  );

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final style = _style;
      final square = await renderArt(style, const Size(800, 800));
      final wide = await renderArt(style, const Size(1400, 656));
      await bridge.files.write('art/square.png', square);
      await bridge.files.write('art/wide.png', wide);
      await bridge.storage.set(artCaptionKey, style.caption);
      await reloadWidgets('ArtWidget');
      if (mounted) {
        DemoScope.of(context).report(
          'Sent art to the widget',
          '${(square.length + wide.length) ~/ 1024} KB of PNG',
        );
        toast(context, 'Sent! Check the "Flutter art" widget.');
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1400 / 656,
            child: CustomPaint(painter: ArtPainter(_style)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final name in palettes.keys)
                      ChoiceChip(
                        label: Text(name),
                        selected: name == _palette,
                        avatar: CircleAvatar(
                          backgroundColor: palettes[name]!.last,
                        ),
                        onSelected: (_) => setState(() => _palette = name),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 4,
                  children: [
                    for (final emoji in _emojis)
                      ChoiceChip(
                        label: Text(
                          emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                        showCheckmark: false,
                        selected: emoji == _emoji,
                        onSelected: (_) => setState(() => _emoji = emoji),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _caption,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: 'Caption',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Shuffle bubbles',
                      icon: const Icon(Icons.shuffle_rounded),
                      onPressed: () => setState(() => _seed++),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _sending || !isIOS ? null : _send,
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: const Text('Send to widget'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
