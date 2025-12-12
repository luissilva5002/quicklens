import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path/path.dart' as p;

class PdfQuestionExtractor {
  // ---------------------------------------------------------------------------
  // ENTRY POINT 1: FILE PATH (Mobile/Desktop)
  // ---------------------------------------------------------------------------
  static List<Map<String, dynamic>> extractQuestionsFromFile(String path) {
    log('DEBUG: Extracting questions from file: $path');
    final bytes = File(path).readAsBytesSync();
    final fileName = p.basename(path);
    return _extractQuestionsAndDump(bytes, fileName, path);
  }

  // ---------------------------------------------------------------------------
  // ENTRY POINT 2: BYTES (Web)
  // ---------------------------------------------------------------------------
  static List<Map<String, dynamic>> extractQuestionsFromBytes(
      Uint8List bytes, String fileName) {
    return _extractQuestionsAndDump(bytes, fileName, null);
  }

  static List<Map<String, dynamic>> _extractQuestionsAndDump(
      Uint8List bytes, String fileName, String? originalPath) {

    // 1. Extract
    final results = _extractQuestionsFromBytesInternal(bytes, fileName);

    // 2. Dump (Logic handled for both Web and IO)
    final String jsonOutput = const JsonEncoder.withIndent('  ').convert(results);

    if (kIsWeb || originalPath == null) {
      log('✅ SUCCESS (Web/Bytes): Extracted ${results.length} questions.');
      // log(jsonOutput); // Uncomment to dump to console
    } else {
      try {
        final String outputPath = p.join(p.dirname(originalPath), 'questions.json');
        File(outputPath).writeAsStringSync(jsonOutput);
        log('✅ SUCCESS: JSON file generated at: $outputPath');
      } catch (e) {
        log('⚠️ WARNING: Could not save JSON file. Dumping to console instead.');
      }
    }
    return results;
  }

  // ---------------------------------------------------------------------------
  // INTERNAL LOGIC
  // ---------------------------------------------------------------------------
  static List<Map<String, dynamic>> _extractQuestionsFromBytesInternal(
      Uint8List bytes, String fileName) {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    List<_StyledLine> allLines = [];

    // --- STEP 1: Extract Lines ---
    for (int i = 0; i < document.pages.count; i++) {
      List<TextLine> textLines = PdfTextExtractor(document)
          .extractTextLines(startPageIndex: i, endPageIndex: i);

      for (var line in textLines) {
        bool isBold = false;
        String text = line.text;
        for (var word in line.wordCollection) {
          if (word.fontStyle.contains(PdfFontStyle.bold)) {
            isBold = true;
            break;
          }
        }
        allLines.add(_StyledLine(
          text: text,
          isBold: isBold,
          pageIndex: i + 1,
          bounds: line.bounds,
        ));
      }
    }
    document.dispose();

    // --- STEP 2: Group into Blocks ---
    List<List<_StyledLine>> blocks = _splitIntoBlocks(allLines);

    // --- STEP 3: Parse Blocks ---
    List<Map<String, dynamic>> results = [];

    for (var block in blocks) {
      // A. Try parsing as True/False Group
      var tfResult = _parseTrueFalseGroup(block, fileName);
      if (tfResult != null) {
        results.add(tfResult);
        continue;
      }

      // B. Try parsing as Multiple Choice
      var mcResult = _parseMultipleChoice(block, fileName);
      if (mcResult != null) {
        results.add(mcResult);
      }
    }

    return results;
  }

  static List<List<_StyledLine>> _splitIntoBlocks(List<_StyledLine> lines) {
    List<List<_StyledLine>> blocks = [];
    List<_StyledLine> currentBlock = [];

    if (lines.isEmpty) return blocks;
    currentBlock.add(lines[0]);

    for (int i = 1; i < lines.length; i++) {
      var prev = lines[i - 1];
      var curr = lines[i];

      bool newPage = curr.pageIndex != prev.pageIndex;
      double gap = curr.bounds.top - (prev.bounds.top + prev.bounds.height);
      bool bigGap = gap > (prev.bounds.height * 1.5);

      if (newPage || bigGap) {
        if (currentBlock.isNotEmpty) blocks.add(List.from(currentBlock));
        currentBlock = [];
      }
      currentBlock.add(curr);
    }
    if (currentBlock.isNotEmpty) blocks.add(currentBlock);
    return blocks;
  }

  // --- Parsing Helpers ---

  static final RegExp _numberingRegex = RegExp(r"^\s*\d+(?:\.\d+)*\.\s*");
  // Matches "1. Statement Text V" or "1. Statement Text F"
  static final RegExp _tfItemPattern = RegExp(r"^\d+(?:\.\d+)*\.\s*(.+?)\s+(V|F)$");
  static final RegExp _optionPattern = RegExp(r"^[A-Ea-e][\.\)]\s*(.+)$");

  static String _stripNumbering(String text) {
    return text.replaceFirst(_numberingRegex, "").trim();
  }

  // NEW LOGIC: Parses a block into ONE True/False Group object
  static Map<String, dynamic>? _parseTrueFalseGroup(
      List<_StyledLine> block, String fileName) {

    List<String> questionHeader = [];
    List<Map<String, dynamic>> items = [];
    bool foundFirstItem = false;

    // Scan the block
    for (var line in block) {
      final match = _tfItemPattern.firstMatch(line.text);

      if (match != null) {
        // It is a line like "1. statement V"
        foundFirstItem = true;
        String statement = match.group(1)!;
        String vf = match.group(2)!;

        items.add({
          "statement": statement.trim(),
          "answer": vf == "V", // true for V, false for F
          "original_text": line.text
        });
      } else {
        if (!foundFirstItem) {
          // Lines BEFORE the first "1. ... V" are the Question Header
          questionHeader.add(line.text);
        } else {
          // Lines AFTER the first match that DON'T match are likely
          // continuations or noise. For simple TF, we often ignore
          // or append to previous. For now, strict regex match only.
        }
      }
    }

    // If we didn't find any TF items, this is not a TF block
    if (items.isEmpty) return null;

    int page = block.isNotEmpty ? block[0].pageIndex : 1;

    return {
      "type": "true_false_group",
      "question": questionHeader.join(" ").trim(),
      "options": items, // List of {statement, answer}
      "location": {
        "file": fileName,
        "page": page,
      }
    };
  }

  static Map<String, dynamic>? _parseMultipleChoice(
      List<_StyledLine> block, String fileName) {
    List<String> questionLines = [];
    List<_OptionBuilder> optionBuilders = [];
    bool parsingOptions = false;

    int page = block.isNotEmpty ? block[0].pageIndex : 1;

    for (var line in block) {
      final match = _optionPattern.firstMatch(line.text);

      if (match != null) {
        parsingOptions = true;
        String optionText = match.group(1)!.trim();
        optionBuilders.add(_OptionBuilder(
            text: optionText,
            isBold: line.isBold
        ));
      } else {
        if (parsingOptions) {
          if (optionBuilders.isNotEmpty) {
            var currentOpt = optionBuilders.last;
            currentOpt.text += " " + line.text.trim();
            if (line.isBold) currentOpt.isBold = true;
          }
        } else {
          questionLines.add(_stripNumbering(line.text));
        }
      }
    }

    List<String> finalOptions = [];
    String? correctOption;

    for (var opt in optionBuilders) {
      finalOptions.add(opt.text);
      if (opt.isBold) {
        if (correctOption != null) return null;
        correctOption = opt.text;
      }
    }

    if (finalOptions.isEmpty || correctOption == null) {
      return null;
    }

    return {
      "type": "multiple_choice",
      "question": questionLines.join(" ").trim(),
      "options": finalOptions,
      "correct_option": correctOption,
      "location": {
        "file": fileName,
        "page": page,
      }
    };
  }
}

class _StyledLine {
  final String text;
  final bool isBold;
  final int pageIndex;
  final Rect bounds;
  _StyledLine({required this.text, required this.isBold, required this.pageIndex, required this.bounds});
}

class _OptionBuilder {
  String text;
  bool isBold;
  _OptionBuilder({required this.text, required this.isBold});
}