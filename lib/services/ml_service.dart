import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lasertuner/models/experiment_model.dart';
import '../models/prediction_model.dart';

class MLService {
  // Render URL'inizi buraya koyun (deploy sonrası)
  static const String API_URL = 'https://lasertuner-ml-api.onrender.com';

  // Timeout süreleri
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration requestTimeout = Duration(seconds: 15);

  /// API sağlık kontrolü
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$API_URL/health'))
          .timeout(connectionTimeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Health check failed: $e');
      return false;
    }
  }

  /// İstatistikleri getir
  Future<Map<String, dynamic>?> getStatistics() async {
    try {
      final response = await http
          .get(Uri.parse('$API_URL/statistics'))
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Statistics fetch error: $e');
      return null;
    }
  }

  /// Manuel model eğitimi tetikle
  Future<bool> trainModel() async {
    try {
      final response = await http
          .post(Uri.parse('$API_URL/train'))
          .timeout(requestTimeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Model training error: $e');
      return false;
    }
  }

  /// Tahmin al
  Future<PredictionResponse> getPrediction(PredictionRequest request) async {
    try {
      final response = await http
          .post(
            Uri.parse('$API_URL/predict'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(request.toMap()),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return PredictionResponse.fromMap(data);
      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Prediction error: $e');
      rethrow;
    }
  }

  /// Fallback: Basit tahmin (API çalışmazsa)
  PredictionResponse generateFallbackPrediction(PredictionRequest request) {
    Map<String, ProcessParams> predictions = {};
    double thickness = request.materialThickness;

    for (String processType in request.processes) {
      ProcessParams params;

      switch (processType) {
        case 'cutting':
          params = ProcessParams(
            power: _calculateCuttingPower(request.materialType, thickness),
            speed: _calculateCuttingSpeed(request.materialType, thickness),
            passes: _calculatePasses(thickness),
          );
          break;
        case 'engraving':
          params = ProcessParams(
            power: _calculateEngravingPower(request.materialType, thickness),
            speed: _calculateEngravingSpeed(request.materialType, thickness),
            passes: 1,
          );
          break;
        case 'scoring':
          params = ProcessParams(
            power: _calculateScoringPower(request.materialType, thickness),
            speed: _calculateScoringSpeed(request.materialType, thickness),
            passes: 1,
          );
          break;
        default:
          params = ProcessParams(power: 50, speed: 300, passes: 1);
      }

      predictions[processType] = params;
    }

    return PredictionResponse(
      predictions: predictions,
      confidenceScore: 0.5,
      notes:
          '⚠️ Bu tahmin basit bir algoritmaya dayanıyor. ML servisi bağlantısı kurulamadı. Daha iyi sonuçlar için topluluk verilerinden öğrenen ML modelini kullanın.',
    );
  }

  // Materyal bazlı hesaplama yardımcıları
  double _calculateCuttingPower(String material, double thickness) {
    double basePower;
    double multiplier;

    switch (material.toLowerCase()) {
      case 'ahşap':
      case 'ahsap':
        basePower = 65;
        multiplier = 3.0;
        break;
      case 'mdf':
        basePower = 70;
        multiplier = 3.5;
        break;
      case 'plexiglass':
      case 'akrilik':
        basePower = 55;
        multiplier = 2.5;
        break;
      case 'karton':
        basePower = 35;
        multiplier = 2.0;
        break;
      case 'deri':
        basePower = 40;
        multiplier = 1.5;
        break;
      default:
        basePower = 60;
        multiplier = 3.0;
    }

    double power = basePower + (thickness * multiplier);
    return power.clamp(10, 100);
  }

  double _calculateCuttingSpeed(String material, double thickness) {
    double baseSpeed;
    double reduction;

    switch (material.toLowerCase()) {
      case 'ahşap':
      case 'ahsap':
        baseSpeed = 320;
        reduction = 18;
        break;
      case 'mdf':
        baseSpeed = 300;
        reduction = 20;
        break;
      case 'plexiglass':
      case 'akrilik':
        baseSpeed = 380;
        reduction = 25;
        break;
      case 'karton':
        baseSpeed = 450;
        reduction = 15;
        break;
      case 'deri':
        baseSpeed = 400;
        reduction = 12;
        break;
      default:
        baseSpeed = 320;
        reduction = 18;
    }

    double speed = baseSpeed - (thickness * reduction);
    return speed.clamp(50, 600);
  }

  double _calculateEngravingPower(String material, double thickness) {
    return (_calculateCuttingPower(material, thickness) * 0.55).clamp(10, 100);
  }

  double _calculateEngravingSpeed(String material, double thickness) {
    return (_calculateCuttingSpeed(material, thickness) * 1.6).clamp(100, 800);
  }

  double _calculateScoringPower(String material, double thickness) {
    return (_calculateCuttingPower(material, thickness) * 0.75).clamp(10, 100);
  }

  double _calculateScoringSpeed(String material, double thickness) {
    return (_calculateCuttingSpeed(material, thickness) * 1.3).clamp(80, 700);
  }

  int _calculatePasses(double thickness) {
    if (thickness <= 3) return 1;
    if (thickness <= 6) return 2;
    if (thickness <= 10) return 3;
    return 4;
  }
}
