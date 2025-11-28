import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'pdfViewer.dart'; // separate file for navigator
import 'ExtarctorService.dart';

class PdfDropPage extends StatefulWidget {
  const PdfDropPage({super.key});

  @override
  State<PdfDropPage> createState() => _PdfDropPageState();
}

class _PdfDropPageState extends State<PdfDropPage> {
  File? pdf1;
  List<String> chunks = [];
  List<Map<String, Map<double, List<String>>>> compatibles = [];
  bool loading = false;

  Uint8List? imageBytes;
  String extractedText = "";
  bool isLoading = false;

  final String apiKey = 'K88871119188957';

  Future<void> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => pdf1 = File(result.files.single.path!));
      print("PDF selected: ${pdf1!.path}");
      await splitPdfs();
    }
  }

  Future<void> splitPdfs() async {
    if (pdf1 == null) return;

    setState(() {
      loading = true;
      chunks.clear();
    });

    print("Splitting PDF into chunks...");
    chunks.addAll(PdfTextExtractorService.extractParagraphsFromFile(pdf1!.path));
    print("PDF split into ${chunks.length} chunks");

    setState(() {
      loading = false;
    });
  }

  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      print("Image selected: $path");
      await _handleFile(File(path));
    }
  }

  Future<void> _handleFile(File file) async {
    setState(() => isLoading = true);
    final bytes = await file.readAsBytes();
    setState(() => imageBytes = bytes);

    try {
      final text = await _sendToOcrSpace(file);
      print("OCR extracted text:\n$text");
      setState(() => extractedText = text);
    } catch (e) {
      setState(() => extractedText = "OCR failed: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<String> _sendToOcrSpace(File file) async {
    final uri = Uri.parse('https://api.ocr.space/parse/image');
    final request = http.MultipartRequest('POST', uri);
    request.headers['apikey'] = apiKey;
    request.fields['language'] = 'por'; // Portuguese
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

  List<String> tokenize(String text) {
    final cleaned = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zA-Z0-9áàãâéêíóôõúç\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.split(" ").where((w) => w.trim().isNotEmpty).toList();
  }

  final Set<String> stopwords = {
    'a','o','e','de','da','do','que','em','para','com','um','uma','as','os',
    'no','na','nos','nas','por','se','é','dos','das','ao','à','às','ou'
  };

  List<String> removeStopwords(List<String> words) {
    return words.where((w) => !stopwords.contains(w)).toList();
  }

  Future<int> compareChunks() async {
    if (extractedText.isEmpty || chunks.isEmpty) return 0;

    print("Comparing OCR text with PDF chunks...");
    compatibles.clear();

    List<String> ocrWords = removeStopwords(tokenize(extractedText));
    final ocrSet = Set<String>.from(ocrWords);

    int bestIndex = 0;
    double bestScore = -1;

    for (int i = 0; i < chunks.length; i++) {
      String chunk = chunks[i];
      List<String> chunkWords = removeStopwords(tokenize(chunk));
      final chunkSet = Set<String>.from(chunkWords);

      final common = ocrSet.intersection(chunkSet).toList();
      double score = ocrSet.isNotEmpty ? common.length / ocrSet.length : 0;

      compatibles.add({
        chunk: {
          score: common,
        }
      });

      print("Chunk $i: score = $score, common words = $common");

      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }

    print("Most compatible chunk: $bestIndex with score $bestScore");
    setState(() {});

    return bestIndex;
  }

  void showNavigatorAt(int index) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PdfChunkNavigator(
        chunks: chunks,
        compatibles: compatibles,
        initialIndex: index,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Compare Tool')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: pickPdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: Text(pdf1 == null ? 'Pick PDF' : 'PDF Selected'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: pickImage,
                    icon: const Icon(Icons.image),
                    label: const Text("Pick Image"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                children: [
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        int bestIndex = await compareChunks();
                        showNavigatorAt(bestIndex);
                      },
                      icon: const Icon(Icons.compare_arrows),
                      label: const Text("Compare & Show Best Chunk"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
