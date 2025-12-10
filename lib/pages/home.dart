import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:developer';
import 'dart:io';

// External Imports
import '../keys.dart';
import '../services/extractor_service.dart';

// Local Imports
import '../models/paragraph_chunk.dart';
import '../models/scored_chunk.dart';
import '../services/file_service.dart';
import '../services/ocr_service.dart';
import '../services/comparison_service.dart';
import '../widgets/pdf_navigator.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? pdfFile;
  Uint8List? pdfBytes;
  List<ParagraphChunk> chunks = [];
  bool loading = false;

  Uint8List? imageBytes;
  String extractedText = "";
  bool isLoading = false;

  // KEY ADDITION 1: TextEditingController
  late TextEditingController _textController;

  final OcrService _ocrService = OcrService(apiKey: ocrApiKey);
  final ComparisonService _comparisonService = ComparisonService();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: extractedText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // ------------------ PICK PDF & EXTRACT PARAGRAPHS ------------------
  Future<void> pickPdf() async {
    final result = await FileService.pickPdfFile();

    if (result != null) {
      if (kIsWeb) {
        // FIX: Assign Uint8List from FilePickResult.bytes
        pdfBytes = result.bytes;
      } else {
        // FIX: Assign File from FilePickResult.path
        pdfFile = File(result.path!);
      }
      await splitPdf();
    }
  }

  Future<void> splitPdf() async {
    if ((pdfFile == null && !kIsWeb) || (kIsWeb && pdfBytes == null)) return;

    setState(() {
      loading = true;
      chunks.clear();
    });

    log('DEBUG: Starting PDF split...');

    try {
      if (kIsWeb) {
        // FIX: Cast the result explicitly to List<ParagraphChunk>
        final extracted = PdfTextExtractorService.extractParagraphsFromBytes(pdfBytes!);
        chunks.addAll(extracted.cast<ParagraphChunk>());
      } else {
        // FIX: Cast the result explicitly to List<ParagraphChunk>
        final extracted = PdfTextExtractorService.extractParagraphsFromFile(pdfFile!.path);
        chunks.addAll(extracted.cast<ParagraphChunk>());
      }
      log('DEBUG: Split complete. Total chunks: ${chunks.length}');
    } catch (e) {
      log('ERROR: PDF split failed: $e');
    }

    setState(() => loading = false);
  }

  // ------------------ PICK IMAGE (OCR) & OCR API CALLS ------------------
  Future<void> pickImage() async {
    final result = await FileService.pickImageFile();

    if (result == null) return;

    setState(() {
      isLoading = true;
      // FIX: Assign Uint8List from FilePickResult.bytes
      imageBytes = result.bytes;
    });

    try {
      final text = kIsWeb
      // FIX: Use result.path as filename on web
          ? await _ocrService.sendToOcrSpaceWeb(result.bytes!, result.path!)
          : await _ocrService.sendToOcrSpace(File(result.path!));

      setState(() {
        extractedText = text;
        _textController.text = extractedText; // Update controller
      });
    } catch (e) {
      setState(() {
        extractedText = "OCR failed: $e";
        _textController.text = extractedText; // Update controller
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ------------------ TOKENIZER/COMPARISON LOGIC ------------------
  Future<List<ScoredChunk>> compareChunks() async {
    // ExtractedText is kept in sync via _textController.onChanged
    if (extractedText.isEmpty || chunks.isEmpty) {
      log('DEBUG: Comparison skipped. Search text empty or no chunks.');
      return [];
    }

    return _comparisonService.compareChunks(extractedText, chunks);
  }


  // ------------------ SHOW PDF NAVIGATOR ------------------
  void showPdfNavigator(List<ScoredChunk> rankedChunks) {
    if (rankedChunks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No relevant paragraphs found matching the search text.')),
      );
      return;
    }
    if ((pdfFile == null && !kIsWeb) || (kIsWeb && pdfBytes == null)) return;

    log('DEBUG: Navigating to ranked chunk list...');

    if (kIsWeb) {
      final url = FileService.createPdfUrl(pdfBytes!);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TopChunkNavigatorWeb(
              pdfUrl: url,
              rankedChunks: rankedChunks
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TopChunkNavigator(
              pdfPath: pdfFile!.path,
              rankedChunks: rankedChunks
          ),
        ),
      );
    }
  }

  // ------------------ UI ------------------
  @override
  Widget build(BuildContext context) {
    const fmupYellow = Color(0xFFD4A017);
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: fmupYellow,
      foregroundColor: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('QuickLens')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: pickPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(pdfFile == null && pdfBytes == null ? 'Pick PDF' : 'PDF Selected'),
              style: buttonStyle,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: pickImage,
              icon: const Icon(Icons.image),
              label: const Text("Pick Image (OCR)"),
              style: buttonStyle,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12)),
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TextFormField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    hintText: "Enter OCR text or type your own search text here...",
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 16, height: 1.5),
                  onChanged: (newText) {
                    // Update the state variable directly for comparison
                    extractedText = newText;
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                if (chunks.isEmpty || extractedText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a PDF and extract text from an image/type text first.')),
                  );
                  return;
                }

                final rankedChunks = await compareChunks();
                showPdfNavigator(rankedChunks);
              },
              icon: const Icon(Icons.compare_arrows),
              label: const Text("Compare & Show Top Chunks"),
              style: buttonStyle.copyWith(
                padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 20)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}