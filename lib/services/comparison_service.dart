import 'dart:developer';

import '../models/paragraph_chunk.dart';
import '../models/scored_chunk.dart';

class ComparisonService {
  // ------------------ TOKENIZER/COMPARISON LOGIC (F1 Score) ------------------

  List<String> tokenize(String text) {
    final cleaned = text
        .toLowerCase()
    // Allow a-z, 0-9, and common Portuguese characters
        .replaceAll(RegExp(r'[^a-z0-9áàãâéêíóôõúç\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    return cleaned.split(" ").where((w) => w.trim().isNotEmpty).toList();
  }

  // Simplified stop word list for example. Should be much larger for Portuguese.
  final Set<String> stopwords = {'a', 'o', 'e', 'de', 'do', 'da', 'em', 'um', 'uma', 'no', 'na'};

  List<String> filterMeaningful(List<String> words) {
    return words
        .where((w) =>
    w.length > 2 && !stopwords.contains(w) && !RegExp(r'^\d+$').hasMatch(w))
        .toList();
  }

  Map<String, int> wordCounts(List<String> words) {
    final map = <String, int>{};
    for (var w in words) {
      map[w] = (map[w] ?? 0) + 1;
    }
    return map;
  }

  double scoreChunk(List<String> ocrWordsRaw, List<String> chunkWordsRaw, int chunkIndex, int page) {
    final ocrMeaningful = filterMeaningful(ocrWordsRaw);
    final chunkMeaningful = filterMeaningful(chunkWordsRaw);

    final ocrMap = wordCounts(ocrMeaningful);
    final chunkMap = wordCounts(chunkMeaningful);

    int M_Match = 0;
    ocrMap.forEach((word, count) {
      if (chunkMap.containsKey(word)) {
        // Only count the minimum frequency to avoid overcounting based on chunk length
        M_Match += (count < chunkMap[word]! ? count : chunkMap[word]!);
      }
    });

    int M_OCR = ocrMap.values.fold(0, (sum, count) => sum + count);
    int M_Chunk = chunkMap.values.fold(0, (sum, count) => sum + count);

    if (M_OCR == 0 || M_Chunk == 0) {
      // log('SCORE | Index: $chunkIndex (Page $page) | Score: 0.0');
      return 0.0;
    }

    // Recall (R): How many words in the search text were found in the chunk
    final double R = M_Match / M_OCR;
    // Precision (P): How many words in the chunk were also in the search text
    final double P = M_Match / M_Chunk;

    if (P + R == 0) {
      // log('SCORE | Index: $chunkIndex (Page $page) | Score: 0.0');
      return 0.0;
    }

    // F1 Score: Harmonic mean of Precision and Recall
    final double F1_Score = 2 * (P * R) / (P + R);

    log('SCORE | Index: $chunkIndex (Page $page) | Score: ${F1_Score.toStringAsFixed(4)}');

    return F1_Score;
  }

  // Returns a ranked list of ScoredChunk objects
  Future<List<ScoredChunk>> compareChunks(String extractedText, List<ParagraphChunk> chunks) async {
    log('\n############################################');
    log('DEBUG: Starting Chunk Comparison...');

    List<String> ocrWordsRaw = tokenize(extractedText);

    List<ScoredChunk> scoredList = [];

    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      List<String> chunkWordsRaw = tokenize(chunk.text);

      double score = scoreChunk(ocrWordsRaw, chunkWordsRaw, i, chunk.page);

      if (score > 0.01) { // Apply a minimal threshold to reduce noise
        scoredList.add(ScoredChunk(chunk: chunk, score: score));
      }
    }

    // Sort the list by score in descending order
    scoredList.sort((a, b) => b.score.compareTo(a.score));

    log('\nDEBUG: Comparison Finished. Total relevant chunks found: ${scoredList.length}');
    scoredList.take(5).forEach((sc) {
      log('  RANKED RESULT | Rank: ${scoredList.indexOf(sc) + 1}, Score: ${sc.score.toStringAsFixed(4)}, Page: ${sc.chunk.page}');
    });
    log('############################################\n');

    return scoredList;
  }
}