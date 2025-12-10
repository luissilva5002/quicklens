import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

const String _modelAssetPath = 'assets/all_minilm_l6_v2.tflite';
const String _vocabAssetPath = 'assets/vocab.txt';

// The expected vector dimension (384 for all-MiniLM-L6-v2)
const int _vectorDimension = 384;
// The maximum sequence length the model accepts (typically 128 or 256 for Mini-LM)
const int _maxSequenceLength = 128;

class TFLiteVectorService {
  late Interpreter _interpreter;
  late List<String> _vocab;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  /// Loads the TFLite model and the vocabulary file from assets.
  Future<void> loadModel() async {
    try {
      // Load TFLite Model
      _interpreter = await Interpreter.fromAsset(_modelAssetPath);

      // Load Vocabulary (required for BERT-style tokenization)
      final String vocabString = await rootBundle.loadString(_vocabAssetPath);
      _vocab = vocabString.split('\n').map((line) => line.trim()).toList();

      _isLoaded = true;
      print('Mini-LM TFLite Model and Vocab loaded successfully.');
    } catch (e) {
      _isLoaded = false;
      print('Error loading TFLite assets: $e');
      rethrow;
    }
  }

  Future<List<double>> vectorizeText(String text) async {
    if (!_isLoaded) {
      throw StateError('Model is not loaded. Call loadModel() first.');
    }

    final List<List<int>> inputIds = _simpleTokenize(text);

    final outputTensor = List<List<List<double>>>.filled(
        1,
        List<List<double>>.filled(
            _maxSequenceLength,
            List<double>.filled(_vectorDimension, 0.0)
        )
    );

    _interpreter.run(inputIds, outputTensor);
    final List<double> finalEmbedding = _meanPooling(outputTensor[0]);

    return finalEmbedding;
  }

  List<List<int>> _simpleTokenize(String text) {
    return List<List<int>>.filled(
        1, List<int>.filled(_maxSequenceLength, 0)); // [1, 128]
  }

  // Implements Mean Pooling across the sequence
  List<double> _meanPooling(List<List<double>> tokenEmbeddings) {
    List<double> pooledVector = List<double>.filled(_vectorDimension, 0.0);
    int validTokens = 0; // Tracks tokens that aren't padding (optional optimization)

    for (int i = 0; i < tokenEmbeddings.length; i++) {
      for (int j = 0; j < _vectorDimension; j++) {
        pooledVector[j] += tokenEmbeddings[i][j];
      }
      validTokens++;
    }

    // Divide the sum by the number of tokens to get the average
    if (validTokens > 0) {
      for (int j = 0; j < _vectorDimension; j++) {
        pooledVector[j] /= validTokens;
      }
    }
    return pooledVector;
  }

  void dispose() {
    _interpreter.close();
  }
}