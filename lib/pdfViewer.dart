import 'dart:io';
import 'package:flutter/material.dart';

class PdfChunkNavigator extends StatefulWidget {
  final List<String> chunks;
  final List<Map<String, Map<double, List<String>>>> compatibles;
  final int initialIndex;

  const PdfChunkNavigator({
    super.key,
    required this.chunks,
    required this.compatibles,
    this.initialIndex = 0,
  });

  @override
  State<PdfChunkNavigator> createState() => _PdfChunkNavigatorState();
}

class _PdfChunkNavigatorState extends State<PdfChunkNavigator> {
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
  }

  void nextChunk() {
    setState(() {
      if (currentIndex < widget.chunks.length - 1) currentIndex++;
    });
  }

  void previousChunk() {
    setState(() {
      if (currentIndex > 0) currentIndex--;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chunks.isEmpty) {
      return const Center(child: Text("No chunks available"));
    }

    final chunk = widget.chunks[currentIndex];

    List<String> compatibleWords = [];
    for (var map in widget.compatibles) {
      if (map.containsKey(chunk)) {
        final inner = map[chunk]!;
        final score = inner.keys.first;
        compatibleWords = inner[score]!;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text("Chunk ${currentIndex + 1}/${widget.chunks.length}")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: RichText(
                      text: TextSpan(
                        children: chunk.split(' ').map((word) {
                          final isHighlight = compatibleWords
                              .map((w) => w.toLowerCase())
                              .contains(word.toLowerCase());
                          return TextSpan(
                            text: '$word ',
                            style: TextStyle(
                              backgroundColor: isHighlight ? Colors.yellowAccent : Colors.transparent,
                              fontSize: 18,
                              color: Colors.black,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: previousChunk,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("Previous"),
                ),
                Text(
                  "Chunk ${currentIndex + 1} / ${widget.chunks.length}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: nextChunk,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text("Next"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
