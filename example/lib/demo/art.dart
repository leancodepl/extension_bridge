import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// What the Flutter-painted widget shows.
@immutable
final class const ArtStyle({
  required final List<Color> colors,
  required final String emoji,
  required final String caption,
  final int seed = 0,
});

/// The palettes to choose from.
const palettes = <String, List<Color>>{
  'Dusk': [Color(0xFF3F51B5), Color(0xFFE91E63)],
  'Ocean': [Color(0xFF006064), Color(0xFF03A9F4)],
  'Sunset': [Color(0xFFFF6F00), Color(0xFFD81B60)],
  'Forest': [Color(0xFF1B5E20), Color(0xFF9CCC65)],
  'Night': [Color(0xFF0D0D1A), Color(0xFF4527A0)],
};

/// Paints [style]; used for the in-app preview and the widget's PNG.
class ArtPainter(
  /// What to paint.
  final ArtStyle style,
) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: style.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );

    // Soft bubbles, the same for the same seed.
    final random = Random(style.seed);
    final unit = size.shortestSide;
    for (var i = 0; i < 9; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        unit * (0.08 + random.nextDouble() * 0.3),
        Paint()
          ..color = Colors.white.withValues(
            alpha: 0.05 + random.nextDouble() * 0.12,
          ),
      );
    }

    final emoji = TextPainter(
      text: TextSpan(
        text: style.emoji,
        style: TextStyle(fontSize: unit * 0.42),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    emoji.paint(
      canvas,
      Offset(
        (size.width - emoji.width) / 2,
        (size.height - emoji.height) / 2 - unit * 0.08,
      ),
    );

    final caption = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: style.caption,
            style: TextStyle(
              fontSize: unit * 0.085,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          TextSpan(
            text: '\nPainted by Flutter',
            style: TextStyle(
              fontSize: unit * 0.05,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: size.width - unit * 0.16);
    caption.paint(
      canvas,
      Offset(unit * 0.08, size.height - caption.height - unit * 0.07),
    );
  }

  @override
  bool shouldRepaint(ArtPainter oldDelegate) => oldDelegate.style != style;
}

/// Renders [style] into a PNG of [size] pixels.
Future<Uint8List> renderArt(ArtStyle style, Size size) async {
  final recorder = ui.PictureRecorder();
  ArtPainter(style).paint(Canvas(recorder), size);
  final image = await recorder.endRecording().toImage(
    size.width.round(),
    size.height.round(),
  );
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return png!.buffer.asUint8List();
}
