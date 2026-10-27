@Tags(['tools'])
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the launcher icon PNGs into assets/brand/:
///   flutter test --run-skipped --tags tools --update-goldens test/tools
/// then `dart run flutter_launcher_icons`.
void main() {
  const background = Color(0xFF3949AB);
  const backgroundLight = Color(0xFF5C6BC0);

  Future<void> render(
    WidgetTester tester,
    String name,
    Widget child, {
    double size = 1024,
  }) async {
    tester.view
      ..physicalSize = Size(size, size)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(child: child),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('../../assets/brand/$name.png'),
    );
  }

  testWidgets('full icon', (tester) async {
    await render(
      tester,
      'icon_square',
      const CustomPaint(
        size: Size.square(1024),
        painter: _IconPainter(
          background: background,
          backgroundLight: backgroundLight,
          inset: 0.2,
        ),
      ),
    );
  });

  testWidgets('adaptive foreground', (tester) async {
    // Adaptive icons are cropped to the inner 66 %, so the glyph is smaller.
    await render(
      tester,
      'icon_foreground',
      const CustomPaint(
        size: Size.square(1024),
        painter: _IconPainter(inset: 0.3),
      ),
    );
  });

  testWidgets('adaptive monochrome', (tester) async {
    await render(
      tester,
      'icon_monochrome',
      const CustomPaint(
        size: Size.square(1024),
        painter: _IconPainter(inset: 0.3, monochrome: true),
      ),
    );
  });
}

/// A chat bubble holding a grid of media tiles, one of which has become a
/// sparkle: media being tidied up.
class _IconPainter extends CustomPainter {
  const _IconPainter({
    required this.inset,
    this.background,
    this.backgroundLight,
    this.monochrome = false,
  });

  final double inset;
  final Color? background;
  final Color? backgroundLight;
  final bool monochrome;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    if (background != null) {
      final rect = Offset.zero & size;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(s * 0.22)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [backgroundLight!, background!],
          ).createShader(rect),
      );
    }

    const white = Color(0xFFFFFFFF);
    final accent = monochrome ? white : const Color(0xFFFFB74D);
    final tile = monochrome ? white : const Color(0xFF3949AB);
    final tileSoft = monochrome ? white : const Color(0xFF9FA8DA);

    // Bubble.
    final left = s * inset;
    final top = s * inset;
    final right = s * (1 - inset);
    final bottom = s * (1 - inset) - s * 0.06;
    final bubble = RRect.fromLTRBR(
      left,
      top,
      right,
      bottom,
      Radius.circular(s * 0.11),
    );
    final tail = Path()
      ..moveTo(left + s * 0.08, bottom - s * 0.02)
      ..lineTo(left + s * 0.02, bottom + s * 0.09)
      ..lineTo(left + s * 0.2, bottom - s * 0.02)
      ..close();
    final bubblePaint = Paint()..color = white;
    if (monochrome) {
      final stroke = Paint()
        ..color = white
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.035
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(
        Path.combine(PathOperation.union, Path()..addRRect(bubble), tail),
        stroke,
      );
    } else {
      canvas
        ..drawRRect(bubble, bubblePaint)
        ..drawPath(tail, bubblePaint);
    }

    // 2 x 2 tiles.
    final pad = s * 0.075;
    final gap = s * 0.04;
    final cell = ((right - left) - 2 * pad - gap) / 2;
    final rows = ((bottom - top) - 2 * pad - gap) / 2;
    for (var r = 0; r < 2; r++) {
      for (var c = 0; c < 2; c++) {
        final x = left + pad + c * (cell + gap);
        final y = top + pad + r * (rows + gap);
        final rect = Rect.fromLTWH(x, y, cell, rows);
        if (r == 0 && c == 1) {
          _sparkle(canvas, rect.center, math.min(cell, rows) * 0.62, accent);
          continue;
        }
        final paint = Paint()..color = (r + c).isEven ? tile : tileSoft;
        if (monochrome) {
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.025;
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(s * 0.035)),
          paint,
        );
      }
    }
  }

  void _sparkle(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    const points = 4;
    for (var i = 0; i < points * 2; i++) {
      final angle = -math.pi / 2 + i * math.pi / points;
      final radius = i.isEven ? r : r * 0.3;
      final p = c + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawCircle(
      c + Offset(r * 0.75, r * 0.7),
      r * 0.16,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
