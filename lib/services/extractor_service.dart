import 'dart:io';
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';

// FIX: Import the centralized model definition
import '../models/paragraph_chunk.dart';

class PdfTextExtractorService {
  /// Extracts paragraphs from the PDF at [path], preserving the page number for each paragraph.
  static List<ParagraphChunk> extractParagraphsFromFile(String path) {
    final bytes = File(path).readAsBytesSync();
    return _extractParagraphsFromBytesInternal(bytes);
  }

  /// Extracts paragraphs from the PDF [bytes] for web, preserving the page number.
  static List<ParagraphChunk> extractParagraphsFromBytes(Uint8List bytes) {
    return _extractParagraphsFromBytesInternal(bytes);
  }

  // Internal helper to avoid code duplication
  static List<ParagraphChunk> _extractParagraphsFromBytesInternal(Uint8List bytes) {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    List<ParagraphChunk> paragraphs = [];

    for (int pageIndex = 0; pageIndex < document.pages.count; pageIndex++) {
      // Note: PdfTextExtractor uses the document object
      final String pageText = PdfTextExtractor(document).extractText(
        startPageIndex: pageIndex,
        endPageIndex: pageIndex,
      );

      final List<String> pageParagraphs = _splitIntoParagraphs(pageText);

      for (final p in pageParagraphs) {
        paragraphs.add(
          ParagraphChunk(
            // Key Fix: Store page as 1-based page number
            page: pageIndex + 1,
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