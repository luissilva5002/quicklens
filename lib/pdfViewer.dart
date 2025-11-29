import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class PdfChunkNavigator extends StatefulWidget {
  final String pdfPath;
  final int targetPage;

  const PdfChunkNavigator({
    super.key,
    required this.pdfPath,
    required this.targetPage,
  });

  @override
  State<PdfChunkNavigator> createState() => _PdfChunkNavigatorState();
}

class _PdfChunkNavigatorState extends State<PdfChunkNavigator> {
  late PdfController controller;

  @override
  void initState() {
    super.initState();

    controller = PdfController(
      document: PdfDocument.openFile(widget.pdfPath),
      initialPage: widget.targetPage,
    );

    // ensure the correct scroll happens AFTER rendering
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        controller.jumpToPage(widget.targetPage);
      });
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("PDF Viewer – Page ${widget.targetPage}"),
      ),
      body: PdfView(
        controller: controller,
        scrollDirection: Axis.vertical,
      ),
    );
  }
}
