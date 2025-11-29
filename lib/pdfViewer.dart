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
  double currentPageFraction = 0.0; // allow fractional page for smooth dragging
  int totalPages = 0;

  @override
  void initState() {
    super.initState();

    controller = PdfController(
      document: PdfDocument.openFile(widget.pdfPath),
      initialPage: widget.targetPage,
    );

    currentPageFraction = widget.targetPage.toDouble();

    controller.document.then((doc) {
      setState(() => totalPages = doc.pagesCount);
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void jumpToFractionPage(double pageFraction) {
    // Clamp fraction between 0 and totalPages - 1
    pageFraction = pageFraction.clamp(0.0, (totalPages - 1).toDouble());
    setState(() => currentPageFraction = pageFraction);

    // Animate to the nearest page (PdfController only accepts integers)
    int nearestPage = currentPageFraction.round();
    controller.animateToPage(
      nearestPage,
      duration: const Duration(milliseconds: 50),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    int currentPage = currentPageFraction.round();

    return Scaffold(
      appBar: AppBar(
        title: Text("PDF Viewer – Page ${currentPage + 1}/$totalPages"),
      ),
      body: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: PdfView(
              controller: controller,
              scrollDirection: Axis.vertical,
            ),
          ),
          // Vertical scrollbar
          Container(
            width: 16,
            color: Colors.black12,
            child: LayoutBuilder(
              builder: (context, constraints) {
                double thumbHeight =
                totalPages > 0 ? constraints.maxHeight / totalPages * 3 : 0;

                return GestureDetector(
                  onVerticalDragUpdate: (details) {
                    double scaleFactor = (totalPages - 1) / (constraints.maxHeight - thumbHeight);
                    double pageFraction = currentPageFraction + details.delta.dy * scaleFactor;
                    jumpToFractionPage(pageFraction);
                  },
                  child: Stack(
                    children: [
                      Positioned(
                        top: ((currentPageFraction / (totalPages - 1)) *
                            (constraints.maxHeight - thumbHeight)),
                        left: 2,
                        right: 2,
                        child: Container(
                          height: thumbHeight,
                          decoration: BoxDecoration(
                            color: Colors.grey[600],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
