import 'package:flutter/material.dart';
import 'dart:developer';
import '../models/scored_chunk.dart';
import 'pdf_viewer.dart';

// ------------------ NEW CONTAINER FOR RANKED NAVIGATION (MOBILE) ------------------
class TopChunkNavigator extends StatefulWidget {
  final String pdfPath;
  final List<ScoredChunk> rankedChunks;

  const TopChunkNavigator({
    super.key,
    required this.pdfPath,
    required this.rankedChunks,
  });

  @override
  State<TopChunkNavigator> createState() => _TopChunkNavigatorState();
}

class _TopChunkNavigatorState extends State<TopChunkNavigator> {
  int currentRankIndex = 0; // 0-based index for the rankedChunks list

  void _navigateToRank(int index) {
    setState(() {
      currentRankIndex = index.clamp(0, widget.rankedChunks.length - 1);
      log('DEBUG: Navigating to Rank ${currentRankIndex + 1}');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rankedChunks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('No Matches Found')),
        body: const Center(child: Text('No relevant paragraphs found in the PDF.')),
      );
    }

    final currentChunk = widget.rankedChunks[currentRankIndex];
    final targetPageIndex0Based = currentChunk.chunk.page;

    // Use the existing PDF viewer, passing the target page
    return PdfChunkNavigator(
      key: ValueKey(currentChunk.chunk.page),
      pdfPath: widget.pdfPath,
      targetPage: targetPageIndex0Based,
      navigationControls: _buildNavigationControls(),
      currentRank: currentRankIndex + 1,
      maxRank: widget.rankedChunks.length,
      currentScore: currentChunk.score,
    );
  }

  Widget _buildNavigationControls() {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: currentRankIndex > 0
                ? () => _navigateToRank(currentRankIndex - 1)
                : null,
          ),
          Text(
            'Rank ${currentRankIndex + 1} / ${widget.rankedChunks.length}',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
            onPressed: currentRankIndex < widget.rankedChunks.length - 1
                ? () => _navigateToRank(currentRankIndex + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

// ------------------ NEW CONTAINER FOR RANKED NAVIGATION (WEB) ------------------
class TopChunkNavigatorWeb extends StatefulWidget {
  final String pdfUrl;
  final List<ScoredChunk> rankedChunks;

  const TopChunkNavigatorWeb({
    super.key,
    required this.pdfUrl,
    required this.rankedChunks,
  });

  @override
  State<TopChunkNavigatorWeb> createState() => _TopChunkNavigatorWebState();
}

class _TopChunkNavigatorWebState extends State<TopChunkNavigatorWeb> {
  int currentRankIndex = 0;

  void _navigateToRank(int index) {
    setState(() {
      currentRankIndex = index.clamp(0, widget.rankedChunks.length - 1);
      log('DEBUG: Navigating to Rank ${currentRankIndex + 1}');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rankedChunks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('No Matches Found')),
        body: const Center(child: Text('No relevant paragraphs found in the PDF.')),
      );
    }

    final currentChunk = widget.rankedChunks[currentRankIndex];
    final targetPageIndex0Based = currentChunk.chunk.page;

    return PdfChunkNavigatorWeb(
      key: ValueKey(currentChunk.chunk.page),
      pdfUrl: widget.pdfUrl,
      targetPage: targetPageIndex0Based,
      navigationControls: _buildNavigationControls(),
      currentRank: currentRankIndex + 1,
      maxRank: widget.rankedChunks.length,
      currentScore: currentChunk.score,
    );
  }

  Widget _buildNavigationControls() {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: currentRankIndex > 0
                ? () => _navigateToRank(currentRankIndex - 1)
                : null,
          ),
          Text(
            'Rank ${currentRankIndex + 1} / ${widget.rankedChunks.length}',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
            onPressed: currentRankIndex < widget.rankedChunks.length - 1
                ? () => _navigateToRank(currentRankIndex + 1)
                : null,
          ),
        ],
      ),
    );
  }
}