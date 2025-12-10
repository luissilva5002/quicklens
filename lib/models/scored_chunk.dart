import 'paragraph_chunk.dart';

class ScoredChunk {
  final ParagraphChunk chunk;
  final double score;

  ScoredChunk({required this.chunk, required this.score});
}