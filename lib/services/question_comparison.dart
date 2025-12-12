import 'dart:developer';
import 'dart:math' as math;
import '../models/paragraph_chunk.dart';
import '../models/scored_chunk.dart';

class ComparisonService {
  // ==============================================================================
  // SHARED: TOKENIZATION
  // ==============================================================================

  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áàãâéêíóôõúç\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(" ")
        .where((w) =>
    w
        .trim()
        .isNotEmpty)
        .toList();
  }

  final Set<String> _stopwords = {
    'a', 'o', 'e', 'de', 'do', 'da', 'em', 'um', 'uma', 'no', 'na',
    'os', 'as', 'dos', 'das', 'nos', 'nas', 'por', 'para', 'com', 'se', 'que'
  };

  Set<String> _createBagOfWords(String text) {
    final rawTokens = _tokenize(text);
    return rawTokens
        .where((w) =>
    w.length > 2 &&
        !_stopwords.contains(w) &&
        !RegExp(r'^\d+$').hasMatch(w))
        .toSet();
  }

  // ==============================================================================
  // METHOD A: Standard Paragraph Comparison (F1 Score)
  // Used when "Infer to JSON" is UNCHECKED
  // ==============================================================================

  Future<List<ScoredChunk>> compareChunks(String extractedText,
      List<ParagraphChunk> chunks) async {
    log('DEBUG: Running Standard F1 Comparison...');
    // ... [Insert your existing F1 logic here if you want to keep it exact] ...
    // For brevity, I will use a simplified version, but you can keep your original logic.

    // RE-IMPLEMENTING your specific logic for compatibility:
    List<String> ocrWordsRaw = _tokenize(extractedText);
    List<ScoredChunk> scoredList = [];

    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      // Reuse your logic logic or similar F1 calculation
      double score = _calculateF1Score(ocrWordsRaw, _tokenize(chunk.text));
      if (score > 0.01) {
        scoredList.add(ScoredChunk(chunk: chunk, score: score));
      }
    }
    scoredList.sort((a, b) => b.score.compareTo(a.score));
    return scoredList;
  }

  double _calculateF1Score(List<String> ocrTokens, List<String> chunkTokens) {
    // Simplified F1 implementation for brevity
    final ocrSet = ocrTokens.where((w) => !_stopwords.contains(w)).toSet();
    final chunkSet = chunkTokens.where((w) => !_stopwords.contains(w)).toSet();
    if (ocrSet.isEmpty || chunkSet.isEmpty) return 0.0;

    final intersection = ocrSet
        .intersection(chunkSet)
        .length;
    final precision = intersection / chunkSet.length;
    final recall = intersection / ocrSet.length;

    if (precision + recall == 0) return 0.0;
    return 2 * (precision * recall) / (precision + recall);
  }

  // ==============================================================================
  // METHOD B: JSON Question Comparison (Jaccard Similarity)
  // Used when "Infer to JSON" is CHECKED
  // ==============================================================================

  Map<String, dynamic>? findBestMatchingQuestion(String ocrText,
      List<Map<String, dynamic>> questions) {
    log('DEBUG: Running Jaccard JSON Comparison...');

    final Set<String> ocrBag = _createBagOfWords(ocrText);

    Map<String, dynamic>? bestMatch;
    double bestScore = -1.0;

    for (var question in questions) {
      // 1. Construct the "Document" text from Question + Options
      String docText = question['question'] ?? "";
      if (question['options'] != null) {
        final List<dynamic> opts = question['options'];
        docText += " " + opts.join(" ");
      }

      // 2. Jaccard Calculation
      final Set<String> docBag = _createBagOfWords(docText);

      double score = 0.0;
      if (ocrBag.isNotEmpty && docBag.isNotEmpty) {
        final intersection = ocrBag
            .intersection(docBag)
            .length;
        final union = ocrBag
            .union(docBag)
            .length;
        score = union == 0 ? 0.0 : intersection / union;
      }

      // 3. Track Best
      if (score > bestScore) {
        bestScore = score;
        bestMatch = question;
      }
    }

    log('DEBUG: Best Jaccard Score: $bestScore');

    // threshold (e.g., 5% similarity)
    if (bestScore > 0.05) {
      return bestMatch;
    }
    return null;
  }
}