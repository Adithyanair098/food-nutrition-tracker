import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/food_prediction.dart';
import '../models/nutrition_info.dart';

// ── Return type ─────────────────────────────────────────────────────────────

class GeminiAnalysisResult {
  final List<FoodPrediction> predictions;

  /// Estimated nutrition per 100 g for the TOP prediction.
  /// TODO M4: Replace with USDA SQLite lookup for the user-confirmed food name.
  final NutritionInfo nutritionPer100g;

  const GeminiAnalysisResult({
    required this.predictions,
    required this.nutritionPer100g,
  });
}

// ── Custom exception ─────────────────────────────────────────────────────────

class GeminiException implements Exception {
  final String message;
  const GeminiException(this.message);

  @override
  String toString() => message;
}

// ── Service ──────────────────────────────────────────────────────────────────

class GeminiService {
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-1.5-flash:generateContent';

  // The prompt asks Gemini to act as a food recognition expert and return
  // a strictly formatted JSON object. responseMimeType enforces JSON output
  // so we never receive markdown-wrapped text.
  static const String _prompt = '''
You are a food recognition expert specialising in Indian cuisine.

Analyse the food in the image. Return ONLY a valid JSON object — no markdown, no explanation, nothing else.

{
  "predictions": [
    {"name": "Dal Makhani",  "confidence": 0.85},
    {"name": "Rajma Curry",  "confidence": 0.10},
    {"name": "Black Lentils","confidence": 0.05}
  ],
  "nutrition_per_100g": {
    "calories":  145,
    "protein_g": 7.2,
    "carbs_g":   18.5,
    "fat_g":     4.1,
    "fiber_g":   3.5
  }
}

Rules:
- Provide 3 to 5 predictions ordered by confidence (highest first).
- Confidence values must sum to exactly 1.0.
- Prefer specific Indian food names (e.g. "Idli", "Chapati", "Palak Paneer").
- The nutrition block contains estimated values for your TOP prediction only, per 100 g.
- If no food is visible, use name "Unknown Food" with confidence 1.0 and zero nutrition.
''';

  Future<GeminiAnalysisResult> analyzeFood(File imageFile) async {
    // 1. Encode image as base64
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    // 2. Build request body
    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'inlineData': {
                'mimeType': 'image/jpeg',
                'data': base64Image,
              },
            },
            {'text': _prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.1,       // Low = consistent, factual output
        'maxOutputTokens': 512,
        'responseMimeType': 'application/json', // Forces clean JSON output
      },
    });

    // 3. Send request
    late http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_endpoint?key=${ApiConfig.geminiApiKey}'),
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 30));
    } on SocketException {
      throw const GeminiException(
          'No internet connection. Please check your network and try again.');
    } on TimeoutException {
      throw const GeminiException(
          'The request timed out. Please try again.');
    }

    // 4. Handle HTTP error codes
    switch (response.statusCode) {
      case 200:
        break; // Success — continue below
      case 400:
        throw const GeminiException('Bad request. Please try a different image.');
      case 401:
        throw const GeminiException(
            'Invalid API key. Open lib/config/api_config.dart and check your key.');
      case 403:
        throw const GeminiException(
            'API access denied. Verify your Gemini API key has the correct permissions.');
      case 429:
        throw const GeminiException(
            'API rate limit reached. Please wait a moment and try again.');
      default:
        throw GeminiException(
            'Server error (${response.statusCode}). Please try again.');
    }

    // 5. Parse Gemini response envelope
    late Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const GeminiException('Unexpected response from AI. Please try again.');
    }

    // 6. Guard against empty candidates (e.g. safety filter triggered)
    final candidates = envelope['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw const GeminiException(
          'The AI could not analyse this image. Please try a clearer food photo.');
    }

    // 7. Extract the inner JSON string Gemini produced
    final text =
        candidates[0]['content']['parts'][0]['text'] as String;

    late Map<String, dynamic> result;
    try {
      result = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw const GeminiException(
          'Could not parse AI response. Please try again.');
    }

    // 8. Build typed objects
    final rawPredictions = result['predictions'] as List<dynamic>;
    if (rawPredictions.isEmpty) {
      throw const GeminiException(
          'No food predictions returned. Please try a clearer photo.');
    }

    final predictions = rawPredictions
        .map((p) => FoodPrediction.fromJson(p as Map<String, dynamic>))
        .toList();

    final nutrition = NutritionInfo.fromJson(
      result['nutrition_per_100g'] as Map<String, dynamic>,
    );

    return GeminiAnalysisResult(
      predictions: predictions,
      nutritionPer100g: nutrition,
    );
  }
}