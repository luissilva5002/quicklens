import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ImageDropPage extends StatefulWidget {
  const ImageDropPage({super.key});

  @override
  State<ImageDropPage> createState() => _ImageDropPageState();
}

class _ImageDropPageState extends State<ImageDropPage> {
  Uint8List? imageBytes;
  String extractedText = "";
  bool isLoading = false;

  final String apiKey = 'K88871119188957';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Image → Text (OCR.space)")),
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: pickImage,
                  child: const Text("Pick Image"),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: DropTarget(
                    onDragDone: (details) async {
                      final path = details.files.first.path;
                      if (path != null) await _handleFile(File(path));
                    },
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blueAccent, width: 3),
                      ),
                      child: imageBytes == null
                          ? const Center(
                        child: Text("Drop an image here or use the button"),
                      )
                          : Image.memory(imageBytes!),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              color: Colors.black12,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SelectableText(
                extractedText.isEmpty
                    ? "Extracted text will appear here"
                    : extractedText,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
