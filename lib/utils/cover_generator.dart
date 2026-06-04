import 'dart:io';
import 'dart:ui' as ui;

class CoverGenerator {
  CoverGenerator._();

  static Future<String> generateDefaultCover({
    required String title,
    required String outputPath,
  }) async {
    const width = 360.0;
    const height = 520.0;
    final colors = _colorsForTitle(title);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final backgroundPaint = ui.Paint()
      ..shader = ui.Gradient.linear(
        const ui.Offset(0, 0),
        const ui.Offset(width, height),
        colors,
      );

    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, width, height),
      backgroundPaint,
    );

    final overlayPaint = ui.Paint()
      ..color = const ui.Color(0x33FFFFFF)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(24, 24, width - 48, height - 48),
        const ui.Radius.circular(18),
      ),
      overlayPaint,
    );

    final titleParagraph = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: ui.TextAlign.center,
        fontSize: 38,
        fontWeight: ui.FontWeight.w700,
        height: 1.22,
        maxLines: 5,
      ),
    )
      ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFFFFFFF)))
      ..addText(_wrapTitle(title));

    final titleLayout = titleParagraph.build()
      ..layout(const ui.ParagraphConstraints(width: width - 64));
    canvas.drawParagraph(
      titleLayout,
      ui.Offset(32, (height - titleLayout.height) / 2 - 24),
    );

    final markParagraph = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: ui.TextAlign.center,
        fontSize: 18,
        fontWeight: ui.FontWeight.w500,
      ),
    )
      ..pushStyle(ui.TextStyle(color: const ui.Color(0xDDFFFFFF)))
      ..addText('WL Reader');
    final markLayout = markParagraph.build()
      ..layout(const ui.ParagraphConstraints(width: width - 64));
    canvas.drawParagraph(markLayout, const ui.Offset(32, height - 80));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();

    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    return file.path;
  }

  static List<ui.Color> _colorsForTitle(String title) {
    final palettes = [
      [const ui.Color(0xFF1F6F78), const ui.Color(0xFF78B7A3)],
      [const ui.Color(0xFF4B5563), const ui.Color(0xFFB45309)],
      [const ui.Color(0xFF14532D), const ui.Color(0xFF65A30D)],
      [const ui.Color(0xFF7C2D12), const ui.Color(0xFFEAB308)],
      [const ui.Color(0xFF0F766E), const ui.Color(0xFF2563EB)],
    ];

    final hash = title.runes.fold<int>(0, (value, rune) => value + rune);
    return palettes[hash % palettes.length];
  }

  static String _wrapTitle(String title) {
    final trimmed = title.trim().isEmpty ? '未命名' : title.trim();
    if (trimmed.length <= 8) {
      return trimmed.split('').join('\n');
    }
    return trimmed.length <= 18 ? trimmed : '${trimmed.substring(0, 18)}…';
  }
}
