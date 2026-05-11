import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:lasertuner/services/remote_config_service.dart';
import '../models/prediction_model.dart';
import '../models/experiment_model.dart';

class GeminiAIService {
  // _model lazy oluşturuluyor: tahmin anında Remote Config zaten fetch etmiş olur
  GenerativeModel? _model;

  GenerativeModel _getModel() {
    final apiKey = RemoteConfigService().geminiApiKey;
    // Her seferinde güncel key ile model oluştur (key değişirse güncellenir)
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 2048,
      ),
    );
    print(
      '✅ Gemini model initialized: gemini-2.0-flash (key length: ${apiKey.length})',
    );
    return _model!;
  }

  /// Gemini ile tahmin al
  Future<PredictionResponse> getPredictionWithGemini(
    PredictionRequest request,
  ) async {
    try {
      print('🤖 Gemini AI ile tahmin alınıyor...');
      print(
        '📋 Request: ${request.machineBrand}, ${request.materialType}, ${request.materialThickness}mm',
      );

      final model = _getModel();
      final prompt = _buildPrompt(request);
      final response = await model.generateContent([Content.text(prompt)]);

      if (response.text == null || response.text!.isEmpty) {
        throw Exception('Gemini boş yanıt verdi');
      }

      print('✅ Gemini yanıtı alındı (${response.text!.length} karakter)');

      final jsonResponse = _parseGeminiResponse(response.text!);
      return _convertToPredictionResponse(jsonResponse, request);
    } catch (e) {
      print('❌ Gemini hatası: $e');
      return _generateFallbackPrediction(request);
    }
  }

  /// Detaylı prompt oluştur
  String _buildPrompt(PredictionRequest request) {
    return '''
Sen bir diode lazer kesim uzmanısın. Aşağıdaki parametrelere göre en uygun lazer kesim ayarlarını JSON formatında öner.

📋 GİRİLEN PARAMETRELER:
- Makine: ${request.machineBrand}
- Lazer Gücü: ${request.laserPower}W (Diode Laser)
- Malzeme: ${request.materialType}
- Kalınlık: ${request.materialThickness}mm
- İşlemler: ${request.processes.join(', ')}

🎯 GÖREV:
Her işlem için aşağıdaki değerleri hesapla:
1. power: Lazer gücü yüzdesi (0-100%)
2. speed: Kesim hızı (mm/s, 1-500 arası)
3. passes: Geçiş sayısı (1-8 arası)

📊 ÖNEMLİ KURALLAR:
- Diode lazerler CO2'ye göre daha zayıftır
- ${request.materialThickness}mm için uygun güç ve hız seç
- ${request.materialType} için optimize et
- Kesme için yüksek güç (70-90%), kazıma için orta güç (40-60%)
- Kalın malzemeler için daha fazla geçiş gerekir (3mm+ için 2-4 geçiş)

ÇIKTI FORMATI (SADECE JSON, BAŞKA HİÇBİR ŞEY YAZMA):
{
  "predictions": {
    ${request.processes.contains('cutting') ? '"cutting": {"power": 85.0, "speed": 200.0, "passes": 3},' : ''}
    ${request.processes.contains('engraving') ? '"engraving": {"power": 45.0, "speed": 350.0, "passes": 1},' : ''}
    ${request.processes.contains('scoring') ? '"scoring": {"power": 60.0, "speed": 280.0, "passes": 1}' : ''}
  },
  "confidence_score": 0.85,
  "notes": "${request.materialThickness}mm ${request.materialType} için önerilen ayarlar.",
  "data_source": "gemini_ai"
}

Sadece istenen işlemler için tahmin yap: ${request.processes.join(', ')}
Yanıtın sadece JSON olsun!
''';
  }

  /// Gemini yanıtını parse et
  Map<String, dynamic> _parseGeminiResponse(String responseText) {
    try {
      print('🔍 Parsing response...');

      String cleanedText =
          responseText
              .replaceAll('```json', '')
              .replaceAll('```', '')
              .replaceAll('json', '')
              .trim();

      final jsonStart = cleanedText.indexOf('{');
      final jsonEnd = cleanedText.lastIndexOf('}') + 1;

      if (jsonStart == -1 || jsonEnd <= jsonStart) {
        throw Exception('JSON formatı bulunamadı');
      }

      cleanedText = cleanedText.substring(jsonStart, jsonEnd);
      print(
        '🔍 Cleaned JSON: ${cleanedText.substring(0, cleanedText.length > 200 ? 200 : cleanedText.length)}...',
      );

      final parsed = jsonDecode(cleanedText);
      print('✅ JSON parsed successfully');

      return parsed;
    } catch (e) {
      print('❌ JSON parse hatası: $e');
      print('📄 Original response: $responseText');
      throw Exception('Gemini yanıtı JSON formatında değil: $e');
    }
  }

  /// JSON'u PredictionResponse'a dönüştür
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

  /// Fallback: API başarısız olursa varsayılan değerler
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

  /// Karşılaştırmalı analiz (Hem API hem Gemini)
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

  /// Gemini ile öneri al (tahmin değil, sadece tavsiye)
  Future<String> getAdviceFromGemini(
    String machineBrand,
    String material,
    double thickness,
  ) async {
    try {
      final model = _getModel();
      final prompt = '''
$machineBrand diode lazer ile $thickness mm kalınlığında $material kesmeyi planlıyorum.
Bana kısa ve öz tavsiyelerde bulun (Türkçe, maksimum 100 kelime).
''';

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? 'Tavsiye alınamadı';
    } catch (e) {
      print('❌ Advice error: $e');
      return 'Gemini bağlantı hatası. Lütfen daha sonra tekrar deneyin.';
    }
  }
}
