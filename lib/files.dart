/*
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'ExtarctorService.dart';

class PdfDropPage extends StatefulWidget {
  const PdfDropPage({super.key});

  @override
  State<PdfDropPage> createState() => _PdfDropPageState();
}

class _PdfDropPageState extends State<PdfDropPage> {
  File? pdf1;
  List<String> chunks = [];
  bool loading = false;

  Future<void> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        pdf1 = File(result.files.single.path!);
      });
    }
  }

  Future<void> splitPdfs() async {
    if (pdf1 == null) return;

    setState(() {
      loading = true;
      chunks.clear();
    });

    if (pdf1 != null) {
      chunks.addAll(
        PdfTextExtractorService.extractParagraphsFromFile(pdf1!.path),
      );
    }

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload & Split PDFs')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () => pickPdf(),
                  child: Text(pdf1 == null ? 'Pick PDF 1' : 'PDF 1 Selected'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : splitPdfs,
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Split into Paragraphs'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: chunks.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(chunks[index]),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

 */
