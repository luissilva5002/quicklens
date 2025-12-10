import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;

class OcrService {
  final String apiKey;

  OcrService({required this.apiKey});

  // --- OCR API CALL (Mobile/Desktop) ---
  Future<String> sendToOcrSpace(File file) async {
    log('DEBUG: Sending image to OCR.space (Mobile/Desktop)...');
    final uri = Uri.parse('https://api.ocr.space/parse/image');
    final request = http.MultipartRequest('POST', uri);
    request.headers['apikey'] = apiKey;
    request.fields['language'] = 'por';
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();
    final respStr = await response.stream.bytesToString();
    return _parseOcrResponse(respStr, response.statusCode);
  }

  // --- OCR API CALL (Web) ---
  Future<String> sendToOcrSpaceWeb(Uint8List bytes, String filename) async {
    log('DEBUG: Sending image to OCR.space (Web)...');
    final uri = Uri.parse('https://api.ocr.space/parse/image');
    final request = http.MultipartRequest('POST', uri);
    request.headers['apikey'] = apiKey;
    request.fields['language'] = 'por';
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final response = await request.send();
    final respStr = await response.stream.bytesToString();
    return _parseOcrResponse(respStr, response.statusCode);
  }

  String _parseOcrResponse(String respStr, int statusCode) {
    final data = json.decode(respStr);

    log('DEBUG: OCR Response Status: $statusCode');

    if (data['IsErroredOnProcessing'] == true) {
      final error = data['ErrorMessage'] ?? 'Unknown OCR error';
      log('ERROR: OCR API Error: $error');
      throw Exception(error);
    }

    final parsedResults = data['ParsedResults'] as List;
    if (parsedResults.isEmpty) return '';

    final extracted = parsedResults.map((r) => r['ParsedText'] ?? '').join('\n');
    log('DEBUG: OCR Extracted Text (${extracted.length} chars): ${extracted.substring(0, extracted.length.clamp(0, 100))}...');
    return extracted;
  }
}