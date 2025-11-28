import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfTextExtractorService {
  /// Extracts all text from the PDF at [path] and returns paragraph chunks.
  static List<String> extractParagraphsFromFile(String path) {
    final bytes = File(path).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes);

    final String fullText = PdfTextExtractor(document).extractText();

    document.dispose();

    return _splitIntoParagraphs(fullText);
  }

  static List<String> _splitIntoParagraphs(String rawText) {
    return rawText
        .split(RegExp(r'\n\s*\n'))   // split on blank lines / double newlines
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
