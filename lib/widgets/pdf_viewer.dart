import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

// ------------------ MODIFIED PDF VIEWER WITH NAVIGATION CONTROLS SLOT (MOBILE) ------------------
class PdfChunkNavigator extends StatefulWidget {
  final String pdfPath;
  final int targetPage;
  final Widget navigationControls;
  final int currentRank;
  final int maxRank;
  final double currentScore;


  const PdfChunkNavigator({
    super.key,
    required this.pdfPath,
    required this.targetPage,
    required this.navigationControls,
    required this.currentRank,
    required this.maxRank,
    required this.currentScore,
  });

  @override
  State<PdfChunkNavigator> createState() => _PdfChunkNavigatorState();
}

class _PdfChunkNavigatorState extends State<PdfChunkNavigator> {
  late PdfController controller;
  double currentPageFraction = 0.0;
  int totalPages = 0;

  @override
  void initState() {
    super.initState();
    _initController(widget.targetPage);
  }

  void _initController(int targetPage) {
    controller = PdfController(
      document: PdfDocument.openFile(widget.pdfPath),
      initialPage: targetPage,
    );

    currentPageFraction = targetPage.toDouble();

    controller.document.then((doc) {
      if(mounted) {
        setState(() => totalPages = doc.pagesCount);
        controller.animateToPage(targetPage, duration: Duration.zero, curve: Curves.ease);
      }
    });
  }

  @override
  void didUpdateWidget(covariant PdfChunkNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetPage != oldWidget.targetPage) {
      controller.animateToPage(
        widget.targetPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => currentPageFraction = widget.targetPage.toDouble());
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void jumpToFractionPage(double pageFraction) {
    pageFraction = pageFraction.clamp(0.0, (totalPages - 1).toDouble());
    setState(() => currentPageFraction = pageFraction);

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("PDF Viewer – Page $currentPage/$totalPages"),
            Text(
              'Rank ${widget.currentRank} (Score: ${widget.currentScore.toStringAsFixed(4)})',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildPdfContent(context),
          ),
          widget.navigationControls,
        ],
      ),
    );
  }

  Widget _buildPdfContent(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(
          child: PdfView(
            controller: controller,
            scrollDirection: Axis.vertical,
          ),
        ),
        Container(
          width: 16,
          color: Colors.black12,
          child: LayoutBuilder(
            builder: (context, constraints) {
              double thumbHeight =
              totalPages > 0 ? constraints.maxHeight / totalPages * 3 : 0;

              if (totalPages <= 1) return const SizedBox.shrink(); // Hide scrollbar for single page

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
    );
  }
}

// ------------------ MODIFIED WEB PDF VIEWER WITH NAVIGATION CONTROLS SLOT ------------------
class PdfChunkNavigatorWeb extends StatefulWidget {
  final String pdfUrl;
  final int targetPage;
  final Widget navigationControls;
  final int currentRank;
  final int maxRank;
  final double currentScore;

  const PdfChunkNavigatorWeb({
    super.key,
    required this.pdfUrl,
    required this.targetPage,
    required this.navigationControls,
    required this.currentRank,
    required this.maxRank,
    required this.currentScore,
  });

  @override
  State<PdfChunkNavigatorWeb> createState() => _PdfChunkNavigatorWebState();
}

class _PdfChunkNavigatorWebState extends State<PdfChunkNavigatorWeb> {
  late PdfController controller;
  double currentPageFraction = 0.0;
  int totalPages = 0;
  bool loading = true;

  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
    _loadPdf(widget.targetPage);
  }

  Future<void> _loadPdf(int targetPage) async {
    setState(() => loading = true);

    if (_pdfBytes == null) {
      final response = await http.get(Uri.parse(widget.pdfUrl));
      if (response.statusCode != 200) {
        throw Exception("Failed to load PDF from web");
      }
      _pdfBytes = response.bodyBytes;
    }

    if (_pdfBytes != null) {
      controller = PdfController(
        document: PdfDocument.openData(_pdfBytes!),
        initialPage: targetPage,
      );
    }

    currentPageFraction = targetPage.toDouble();

    controller.document.then((doc) {
      if(mounted) {
        setState(() {
          totalPages = doc.pagesCount;
          loading = false;
        });
        controller.animateToPage(targetPage, duration: Duration.zero, curve: Curves.ease);
      }
    });
  }

  @override
  void didUpdateWidget(covariant PdfChunkNavigatorWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetPage != oldWidget.targetPage) {
      controller.animateToPage(
        widget.targetPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => currentPageFraction = widget.targetPage.toDouble());
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void jumpToFractionPage(double pageFraction) {
    pageFraction = pageFraction.clamp(0.0, (totalPages - 1).toDouble());
    setState(() => currentPageFraction = pageFraction);

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

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("PDF Viewer – Page $currentPage/$totalPages"),
            Text(
              'Rank ${widget.currentRank} (Score: ${widget.currentScore.toStringAsFixed(4)})',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildPdfContent(context),
          ),
          widget.navigationControls,
        ],
      ),
    );
  }

  Widget _buildPdfContent(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(
          child: PdfView(
            controller: controller,
            scrollDirection: Axis.vertical,
          ),
        ),
        Container(
          width: 16,
          color: Colors.black12,
          child: LayoutBuilder(
            builder: (context, constraints) {
              double thumbHeight =
              totalPages > 0 ? constraints.maxHeight / totalPages * 3 : 0;

              if (totalPages <= 1) return const SizedBox.shrink(); // Hide scrollbar for single page

              return GestureDetector(
                onVerticalDragUpdate: (details) {
                  double scaleFactor =
                      (totalPages - 1) / (constraints.maxHeight - thumbHeight);
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
    );
  }
}