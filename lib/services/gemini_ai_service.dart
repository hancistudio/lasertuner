import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/prediction_model.dart';
import '../models/experiment_model.dart';

class GeminiAIService {
  // Backend URL — Gemini key burada değil, sunucuda güvende
  static const String _backendUrl = 'https://lasertuner-ml-api.onrender.com';

  /// Gemini ile tahmin al (backend üzerinden — key istemcide yok)
  Future<PredictionResponse> getPredictionWithGemini(
    PredictionRequest request,
  ) async {
    try {
      print('🤖 Gemini AI (backend) ile tahmin alınıyor...');
      print(
        '📋 Request: ${request.machineBrand}, ${request.materialType}, ${request.materialThickness}mm',
      );

      final response = await http
          .post(
            Uri.parse('$_backendUrl/gemini-advice'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'machineBrand': request.machineBrand,
              'materialType': request.materialType,
              'materialThickness': request.materialThickness,
              'laserPower': request.laserPower,
              'processes': request.processes,
            }),
          )
          .timeout(const Duration(seconds: 30));

      print('📥 Gemini backend yanıtı: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        return _convertToPredictionResponse(jsonResponse, request);
      } else {
        throw Exception(
          'Backend hata ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Gemini backend hatası: $e');
      return _generateFallbackPrediction(request);
    }
  }

  /// Gemini ile kısa tavsiye al (backend üzerinden)
  Future<String> getAdviceFromGemini(
    String machineBrand,
    String material,
    double thickness,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_backendUrl/gemini-advice'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'machineBrand': machineBrand,
              'materialType': material,
              'materialThickness': thickness,
              'laserPower': 40.0,
              'processes': ['cutting'],
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['notes'] as String? ?? 'Tavsiye alınamadı';
      } else {
        throw Exception('Backend hata: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Advice error: $e');
      return 'Gemini bağlantı hatası. Lütfen daha sonra tekrar deneyin.';
    }
  }

  /// Karşılaştırmalı analiz (Hem ML API hem Gemini)
  Future<Map<String, PredictionResponse>> getComparativePredictions(
    PredictionRequest request,
    Future<PredictionResponse> Function(PredictionRequest) apiPrediction,
  ) async {
    try {
      final results = await Future.wait([
        apiPrediction(request).catchError((e) {
          print('⚠️ API error in comparison: $e');
          return _generateFallbackPrediction(request);
        }),
        getPredictionWithGemini(request).catchError((e) {
          print('⚠️ Gemini error in comparison: $e');
          return _generateFallbackPrediction(request);
        }),
      ]);

      return {'api': results[0], 'gemini': results[1]};
    } catch (e) {
      print('❌ Karşılaştırmalı tahmin hatası: $e');
      rethrow;
    }
  }

  /// Backend JSON yanıtını PredictionResponse'a dönüştür
  PredictionResponse _convertToPredictionResponse(
    Map<String, dynamic> json,
    PredictionRequest request,
  ) {
    Map<String, ProcessParams> predictions = {};

    if (json['predictions'] != null) {
      final predictionsMap = json['predictions'] as Map<String, dynamic>;

      for (var processType in request.processes) {
        if (predictionsMap.containsKey(processType)) {
          final processData =
              predictionsMap[processType] as Map<String, dynamic>;
          predictions[processType] = ProcessParams(
            power: (processData['power'] as num).toDouble(),
            speed: (processData['speed'] as num).toDouble(),
            passes: (processData['passes'] as num).toInt(),
          );
        }
      }
    }

    if (predictions.isEmpty) {
      print('⚠️ No predictions found, using fallback');
      return _generateFallbackPrediction(request);
    }

    return PredictionResponse(
      predictions: predictions,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.75,
      notes: json['notes'] as String? ?? 'Gemini AI tarafından oluşturuldu',
      dataPointsUsed: 0,
      dataSource: 'gemini_ai',
    );
  }

  /// Fallback: backend erişilemezse varsayılan değerler
  PredictionResponse _generateFallbackPrediction(PredictionRequest request) {
    print('🔄 Generating fallback prediction...');

    Map<String, ProcessParams> predictions = {};
    double thickness = request.materialThickness;

    for (var processType in request.processes) {
      if (processType == 'cutting') {
        predictions['cutting'] = ProcessParams(
          power: (80.0 + (thickness * 2)).clamp(10, 100),
          speed: (250.0 - (thickness * 30)).clamp(50, 500),
          passes: (thickness / 2).ceil().clamp(1, 5),
        );
      } else if (processType == 'engraving') {
        predictions['engraving'] = ProcessParams(
          power: (40.0 + (thickness * 1.5)).clamp(10, 100),
          speed: (400.0 - (thickness * 20)).clamp(50, 500),
          passes: 1,
        );
      } else if (processType == 'scoring') {
        predictions['scoring'] = ProcessParams(
          power: (55.0 + (thickness * 1.8)).clamp(10, 100),
          speed: (300.0 - (thickness * 25)).clamp(50, 500),
          passes: 1,
        );
      }
    }

    return PredictionResponse(
      predictions: predictions,
      confidenceScore: 0.65,
      notes:
          'Gemini AI geçici olarak kullanılamıyor. Varsayılan değerler kullanıldı. Test etmenizi öneririz.',
      dataPointsUsed: 0,
      dataSource: 'fallback',
    );
  }
}
