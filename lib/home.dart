import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'pdfViewer.dart'; // updated PdfChunkNavigator
import 'ExtarctorService.dart'; // now returns List<ParagraphChunk>

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? pdf1;
  List<ParagraphChunk> chunks = []; // updated type
  List<Map<String, Map<double, List<String>>>> compatibles = [];
  bool loading = false;

  Uint8List? imageBytes;
  String extractedText = "";
  bool isLoading = false;

  final String apiKey = 'K88871119188957';

  // ----------------------------------------------------------
  // PICK PDF
  // ----------------------------------------------------------
  Future<void> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => pdf1 = File(result.files.single.path!));
      await splitPdfs();
    }
  }

  // ----------------------------------------------------------
  // SPLIT PDF INTO CHUNKS
  // ----------------------------------------------------------
  Future<void> splitPdfs() async {
    if (pdf1 == null) return;

    setState(() {
      loading = true;
      chunks.clear();
    });

    chunks.addAll(
      PdfTextExtractorService.extractParagraphsFromFile(pdf1!.path),
    );

    setState(() => loading = false);
  }

  // ----------------------------------------------------------
  // PICK IMAGE (OCR)
  // ----------------------------------------------------------
  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      await _handleFile(File(path));
    }
  }

  Future<void> _handleFile(File file) async {
    setState(() => isLoading = true);
    final bytes = await file.readAsBytes();
    setState(() => imageBytes = bytes);

    try {
      final text = await _sendToOcrSpace(file);
      setState(() => extractedText = text);
    } catch (e) {
      setState(() => extractedText = "OCR failed: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ----------------------------------------------------------
  // CALL OCR API
  // ----------------------------------------------------------
  Future<String> _sendToOcrSpace(File file) async {
    final uri = Uri.parse('https://api.ocr.space/parse/image');
    final request = http.MultipartRequest('POST', uri);
    request.headers['apikey'] = apiKey;
    request.fields['language'] = 'por';
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();
    final respStr = await response.stream.bytesToString();
    final data = json.decode(respStr);

    if (data['IsErroredOnProcessing'] == true) {
      throw Exception(data['ErrorMessage'] ?? 'Unknown OCR error');
    }

    final parsedResults = data['ParsedResults'] as List;
    if (parsedResults.isEmpty) return '';

    return parsedResults.map((r) => r['ParsedText'] ?? '').join('\n');
  }

  // ----------------------------------------------------------
  // TOKENIZER + STOP WORD REMOVAL
  // ----------------------------------------------------------
  List<String> tokenize(String text) {
    final cleaned = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zA-Z0-9áàãâéêíóôõúç\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    return cleaned.split(" ").where((w) =>
    w
        .trim()
        .isNotEmpty).toList();
  }

  final Set<String> stopwords = { /*
    'a','o','e','de','da','do','que','em','para','com','um','uma','as','os',
    'no','na','nos','nas','por','se','é','dos','das','ao','à','às','ou'
    */
  };

  List<String> removeStopwords(List<String> words) {
    return words.where((w) => !stopwords.contains(w)).toList();
  }

  // ----------------------------------------------------------
  // CHUNK COMPARISON
  // ----------------------------------------------------------
  Future<int> compareChunks() async {
    if (extractedText.isEmpty || chunks.isEmpty) return 0;

    compatibles.clear();

    // Tokenize OCR text
    List<String> ocrWordsRaw = tokenize(extractedText);
    List<String> ocrWords = filterMeaningful(ocrWordsRaw);

    print("OCR meaningful words (${ocrWords.length}): $ocrWords\n");

    int bestIndex = 0;
    double bestScore = -1;

    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      List<String> chunkWordsRaw = tokenize(chunk.text);
      List<String> chunkWords = filterMeaningful(chunkWordsRaw);

      // Compute common words
      final commonWords = ocrWords
          .toSet()
          .intersection(chunkWords.toSet())
          .toList();
      double score = scoreChunk(ocrWordsRaw, chunkWordsRaw);

      // Debug prints
      print("------ Chunk $i (page ${chunk.page}) ------");
      print("Text: ${chunk.text}");
      print("Meaningful words (${chunkWords.length}): $chunkWords");
      print("Common words with OCR (${commonWords.length}): $commonWords");
      print("Score: $score\n");

      compatibles.add({
        chunk.text: {score: chunkWords}
      });

      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }

    print("Best chunk index: $bestIndex with score $bestScore\n");

    setState(() {});
    return bestIndex;
  }

  List<String> filterMeaningful(List<String> words) {
    return words
        .where((w) =>
    w.length > 2 && !stopwords.contains(w) && !RegExp(r'^\d+$').hasMatch(w))
        .toList();
  }

  double scoreChunk(List<String> ocrWordsRaw, List<String> chunkWordsRaw) {
    final ocrMap = wordCounts(filterMeaningful(ocrWordsRaw));
    final chunkMap = wordCounts(filterMeaningful(chunkWordsRaw));

    int matches = 0;
    ocrMap.forEach((word, count) {
      if (chunkMap.containsKey(word)) {
        matches += (count < chunkMap[word]! ? count : chunkMap[word]!);
      }
    });

    int totalOcrWords = ocrMap.values.reduce((a, b) => a + b);
    return totalOcrWords > 0 ? matches / totalOcrWords : 0;
  }

  Map<String, int> wordCounts(List<String> words) {
    final map = <String, int>{};
    for (var w in words) {
      map[w] = (map[w] ?? 0) + 1;
    }
    return map;
  }

  // ----------------------------------------------------------
  // SHOW PDF WITH AUTO-SCROLL TO PAGE (chunk index)
  // ----------------------------------------------------------
  void showNavigatorAt(int index) {
    final chunk = chunks[index];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PdfChunkNavigator(
              pdfPath: pdf1!.path,
              targetPage: chunk.page, // PdfController is 0-based
            ),
      ),
    );
  }

  // ----------------------------------------------------------
// UI
// ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    const fmupYellow = Color(
        0xFFD4A017);
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: fmupYellow,
      foregroundColor: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('QuickLens')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: pickPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(pdf1 == null ? 'Pick PDF' : 'PDF Selected'),
              style: buttonStyle,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: pickImage,
              icon: const Icon(Icons.image),
              label: const Text("Pick Image"),
              style: buttonStyle,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                  child: SelectableText(
                    extractedText.isEmpty
                        ? "OCR text will appear here"
                        : extractedText,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final bestIndex = await compareChunks();
                showNavigatorAt(bestIndex);
              },
              icon: const Icon(Icons.compare_arrows),
              label: const Text("Compare & Show Best Chunk"),
              style: buttonStyle.copyWith(
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(vertical: 20),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}