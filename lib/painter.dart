/*
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class PdfHighlightPainter extends CustomPainter {
  final PdfController controller;
  final List<String> words;

  PdfHighlightPainter({
    required this.controller,
    required this.words,
  });

  @override
  Future<void> paint(Canvas canvas, Size size) async {
    final page = controller.page;
    final text = await page.getText();         // This loads text with bounding boxes

    if (text == null) return;

    final paint = Paint()
      ..color = Colors.yellow.withOpacity(0.35)
      ..style = PaintingStyle.fill;

    for (final block in text.blocks) {
      for (final w in words) {
        if (block.text.toLowerCase().contains(w.toLowerCase())) {
          final rect = Rect.fromLTRB(
            block.bounds.left,
            block.bounds.top,
            block.bounds.right,
            block.bounds.bottom,
          );
          canvas.drawRect(rect, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

 */
