import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:html' as html;
import 'dart:developer';

// Dedicated result model to handle platform differences
class FilePickResult {
  final Uint8List? bytes; // For web or in-memory
  final String? path;    // For mobile/desktop file system (or filename on web)

  FilePickResult({this.bytes, this.path});
}

class FileService {
  // --- PICK PDF ---
  static Future<FilePickResult?> pickPdfFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: kIsWeb,
    );

    if (result != null) {
      final file = result.files.first;
      if (kIsWeb) {
        log('DEBUG: PDF picked (Web). Bytes loaded: ${file.bytes!.length}');
        return FilePickResult(bytes: file.bytes);
      } else if (file.path != null) {
        log('DEBUG: PDF picked (Mobile). Path: ${file.path!}');
        return FilePickResult(path: file.path);
      }
    }
    return null;
  }

  // --- PICK IMAGE ---
  static Future<FilePickResult?> pickImageFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: kIsWeb,
    );

    if (result != null) {
      final file = result.files.first;
      if (kIsWeb) {
        // For web OCR, bytes are needed, and path is used for filename
        return FilePickResult(bytes: file.bytes, path: file.name);
      } else if (file.path != null) {
        return FilePickResult(path: file.path);
      }
    }
    return null;
  }

  // --- CREATE PDF URL (Web only) ---
  static String createPdfUrl(Uint8List pdfBytes) {
    if (kIsWeb) {
      final blob = html.Blob([pdfBytes], 'application/pdf');
      return html.Url.createObjectUrlFromBlob(blob);
    }
    throw UnsupportedError("This function is only for web platform.");
  }
}