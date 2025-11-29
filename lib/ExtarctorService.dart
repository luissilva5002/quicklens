import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Represents one paragraph and the page it belongs to.
class ParagraphChunk {
  final int page;
  final String text;

  ParagraphChunk({
    required this.page,
    required this.text,
  });
}

class PdfTextExtractorService {
  /// Extracts paragraphs from the PDF at [path], preserving the page number for each paragraph.
  static List<ParagraphChunk> extractParagraphsFromFile(String path) {
    final bytes = File(path).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes);

    List<ParagraphChunk> paragraphs = [];

    for (int pageIndex = 0; pageIndex < document.pages.count; pageIndex++) {
      final PdfPage page = document.pages[pageIndex];

      final String pageText = PdfTextExtractor(document).extractText(
        startPageIndex: pageIndex,
        endPageIndex: pageIndex,
      );

      final List<String> pageParagraphs = _splitIntoParagraphs(pageText);

      for (final p in pageParagraphs) {
        paragraphs.add(
          ParagraphChunk(
            page: pageIndex + 1, // real PDF pages are 1-based
            text: p,
          ),
        );
      }
    }

    document.dispose();
    return paragraphs;
  }

  /// Split text into paragraphs based on blank lines.
  static List<String> _splitIntoParagraphs(String rawText) {
    return rawText
        .split(RegExp(r'\n\s*\n')) // Split on blank lines / empty lines
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
