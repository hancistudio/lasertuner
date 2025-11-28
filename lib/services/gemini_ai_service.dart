import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/prediction_model.dart';
import '../models/experiment_model.dart';

class GeminiAIService {
  // 🔑 Google AI Studio'dan alacağınız API Key
  // https://makersuite.google.com/app/apikey
  static const String GEMINI_API_KEY =
      'AIzaSyC18zBV8TLXZThM7UYFRJ3egZU2kpZbZ50';

  late final GenerativeModel _model;

  GeminiAIService() {
    _model = GenerativeModel(
      model: 'gemini-pro',
      apiKey: GEMINI_API_KEY,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 1024,
      ),
    );
  }

  /// Gemini ile tahmin al
  Future<PredictionResponse> getPredictionWithGemini(
    PredictionRequest request,
  ) async {
    try {
      print('🤖 Gemini AI ile tahmin alınıyor...');

      // Prompt oluştur
      final prompt = _buildPrompt(request);

      // Gemini'ye sor
      final response = await _model.generateContent([Content.text(prompt)]);

      if (response.text == null) {
        throw Exception('Gemini yanıt vermedi');
      }

      // JSON'u parse et
      final jsonResponse = _parseGeminiResponse(response.text!);

      // PredictionResponse'a dönüştür
      return _convertToPredictionResponse(jsonResponse, request);
    } catch (e) {
      print('❌ Gemini hatası: $e');
      rethrow;
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
Her işlem için (cutting, engraving, scoring) aşağıdaki değerleri hesapla:
1. **power**: Lazer gücü yüzdesi (0-100%)
2. **speed**: Kesim hızı (mm/dakika, 50-500 arası)
3. **passes**: Geçiş sayısı (1-8 arası)

📊 ÖNEMLİ KURALLAR:
- Diode lazerler CO2'ye göre daha zayıftır
- ${request.materialThickness}mm için uygun güç ve hız seç
- ${request.materialType} için optimize et
- Kesme için yüksek güç, kazıma için orta güç kullan
- Kalın malzemeler için daha fazla geçiş gerekir

🔍 GÜVENİLİRLİK:
- confidence_score: Tahminin güvenilirlik skoru (0.0-1.0)
- notes: Kullanıcıya özel tavsiyelerin (Türkçe)
- data_source: "gemini_ai"

📤 ÇIKTI FORMATI (sadece JSON, başka hiçbir şey yazma):
{
  "predictions": {
    "cutting": {"power": 85.0, "speed": 200.0, "passes": 3},
    "engraving": {"power": 45.0, "speed": 350.0, "passes": 1},
    "scoring": {"power": 60.0, "speed": 280.0, "passes": 1}
  },
  "confidence_score": 0.85,
  "notes": "3mm ${request.materialType} için önerilen ayarlar. İlk denemede düşük güçle başlayın.",
  "data_source": "gemini_ai"
}

Sadece istenen işlemler için tahmin yap: ${request.processes.join(', ')}
''';
  }

  /// Gemini yanıtını parse et
  Map<String, dynamic> _parseGeminiResponse(String responseText) {
    try {
      // Markdown kod bloklarını temizle
      String cleanedText =
          responseText.replaceAll('```json', '').replaceAll('```', '').trim();

      return jsonDecode(cleanedText);
    } catch (e) {
      print('❌ JSON parse hatası: $e');
      print('📄 Response: $responseText');
      throw Exception('Gemini yanıtı JSON formatında değil');
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

    return PredictionResponse(
      predictions: predictions,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.8,
      notes: json['notes'] as String? ?? 'Gemini AI tarafından oluşturuldu',
      dataPointsUsed: 0,
      dataSource: 'gemini_ai',
    );
  }

  /// Karşılaştırmalı analiz (Hem API hem Gemini)
  Future<Map<String, PredictionResponse>> getComparativePredictions(
    PredictionRequest request,
    Future<PredictionResponse> Function(PredictionRequest) apiPrediction,
  ) async {
    try {
      // Paralel olarak her iki tahmini al
      final results = await Future.wait([
        apiPrediction(request),
        getPredictionWithGemini(request),
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
      final prompt = '''
$machineBrand diode lazer ile $thickness mm kalınlığında $material kesmeyi planlıyorum.
Bana kısa ve öz tavsiyelerde bulun (Türkçe, maksimum 100 kelime).
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? 'Tavsiye alınamadı';
    } catch (e) {
      return 'Gemini bağlantı hatası';
    }
  }
}
