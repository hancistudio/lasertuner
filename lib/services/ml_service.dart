import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lasertuner/models/experiment_model.dart';
import '../models/prediction_model.dart';

class MLService {
  // ✅ RENDER.COM PRODUCTION URL
  static const String API_URL = 'https://lasertuner-ml-api.onrender.com';

  // Timeout süreleri
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration requestTimeout = Duration(seconds: 30);

  /// API sağlık kontrolü
  Future<bool> checkHealth() async {
    try {
      print('🔍 Checking API health: $API_URL/health');

      final response = await http
          .get(Uri.parse('$API_URL/health'))
          .timeout(connectionTimeout);

      print('✅ Health check response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Health check failed: $e');
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

  /// Tahmin al
  Future<PredictionResponse> getPrediction(PredictionRequest request) async {
    try {
      print('📤 Sending prediction request to: $API_URL/predict');
      print('📦 Request data: ${jsonEncode(request.toMap())}');

      final response = await http
          .post(
            Uri.parse('$API_URL/predict'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(request.toMap()),
          )
          .timeout(
            requestTimeout,
            onTimeout: () {
              print('⏱️ Request timeout after ${requestTimeout.inSeconds}s');
              throw Exception(
                'İstek zaman aşımına uğradı. '
                'API sunucusu ilk istekte soğuk başlangıç yapıyor olabilir. '
                'Lütfen tekrar deneyin.',
              );
            },
          );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return PredictionResponse.fromMap(data);
      } else if (response.statusCode == 422) {
        final errorData = jsonDecode(response.body);
        throw Exception('Geçersiz veri: ${errorData['detail']}');
      } else if (response.statusCode == 500) {
        throw Exception('Sunucu hatası. Lütfen daha sonra tekrar deneyin.');
      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Prediction error: $e');
      rethrow;
    }
  }

  /// Fallback: Basit tahmin (API çalışmazsa)
  PredictionResponse generateFallbackPrediction(PredictionRequest request) {
    print('⚠️ Using DIODE LASER fallback prediction algorithm');

    Map<String, ProcessParams> predictions = {};
    double thickness = request.materialThickness;

    for (String processType in request.processes) {
      ProcessParams params;

      switch (processType) {
        case 'cutting':
          params = ProcessParams(
            power: _calculateDiodeCuttingPower(request.materialType, thickness),
            speed: _calculateDiodeCuttingSpeed(request.materialType, thickness),
            passes: _calculateDiodePasses(thickness),
          );
          break;
        case 'engraving':
          params = ProcessParams(
            power: _calculateDiodeEngravingPower(
              request.materialType,
              thickness,
            ),
            speed: _calculateDiodeEngravingSpeed(
              request.materialType,
              thickness,
            ),
            passes: 1,
          );
          break;
        case 'scoring':
          params = ProcessParams(
            power: _calculateDiodeScoringPower(request.materialType, thickness),
            speed: _calculateDiodeScoringSpeed(request.materialType, thickness),
            passes: 1,
          );
          break;
        default:
          params = ProcessParams(power: 60, speed: 250, passes: 2);
      }

      predictions[processType] = params;
    }

    return PredictionResponse(
      predictions: predictions,
      confidenceScore: 0.5,
      notes:
          '⚠️ API bağlantısı kurulamadı, diode lazer algoritması kullanıldı. '
          'İnternet bağlantınızı kontrol edin.',
      dataPointsUsed: 0,
      dataSource: 'static_algorithm',
    );
  }

  // ✨ DIODE LASER SPECIFIC CALCULATIONS
  double _calculateDiodeCuttingPower(String material, double thickness) {
    double basePower;
    double multiplier;

    switch (material.toLowerCase()) {
      case 'ahşap':
      case 'ahsap':
      case 'wood':
        basePower = 80;
        multiplier = 4.0;
        break;
      case 'mdf':
        basePower = 85;
        multiplier = 4.5;
        break;
      case 'karton':
      case 'cardboard':
        basePower = 50;
        multiplier = 3.0;
        break;
      case 'deri':
      case 'leather':
        basePower = 70;
        multiplier = 3.5;
        break;
      case 'keçe':
      case 'felt':
        basePower = 60;
        multiplier = 2.5;
        break;
      case 'kumaş':
      case 'kumas':
      case 'fabric':
        basePower = 45;
        multiplier = 2.0;
        break;
      case 'kağıt':
      case 'kagit':
      case 'paper':
        basePower = 40;
        multiplier = 1.5;
        break;
      case 'köpük':
      case 'kopuk':
      case 'foam':
        basePower = 55;
        multiplier = 2.0;
        break;
      case 'mantar':
      case 'cork':
        basePower = 65;
        multiplier = 3.0;
        break;
      default:
        basePower = 75;
        multiplier = 3.5;
    }

    double power = basePower + (thickness * multiplier);
    return power.clamp(10, 100);
  }

  double _calculateDiodeCuttingSpeed(String material, double thickness) {
    double baseSpeed;
    double reduction;

    switch (material.toLowerCase()) {
      case 'ahşap':
      case 'ahsap':
      case 'wood':
        baseSpeed = 300;
        reduction = 30;
        break;
      case 'mdf':
        baseSpeed = 280;
        reduction = 35;
        break;
      case 'karton':
      case 'cardboard':
        baseSpeed = 400;
        reduction = 25;
        break;
      case 'deri':
      case 'leather':
        baseSpeed = 350;
        reduction = 28;
        break;
      case 'keçe':
      case 'felt':
        baseSpeed = 380;
        reduction = 20;
        break;
      case 'kumaş':
      case 'kumas':
      case 'fabric':
        baseSpeed = 420;
        reduction = 15;
        break;
      case 'kağıt':
      case 'kagit':
      case 'paper':
        baseSpeed = 450;
        reduction = 10;
        break;
      case 'köpük':
      case 'kopuk':
      case 'foam':
        baseSpeed = 400;
        reduction = 18;
        break;
      case 'mantar':
      case 'cork':
        baseSpeed = 360;
        reduction = 22;
        break;
      default:
        baseSpeed = 320;
        reduction = 25;
    }

    double speed = baseSpeed - (thickness * reduction);
    return speed.clamp(50, 500); // Diode max 500mm/min
  }

  double _calculateDiodeEngravingPower(String material, double thickness) {
    return (_calculateDiodeCuttingPower(material, thickness) * 0.5).clamp(
      10,
      100,
    );
  }

  double _calculateDiodeEngravingSpeed(String material, double thickness) {
    return (_calculateDiodeCuttingSpeed(material, thickness) + 100).clamp(
      100,
      500,
    );
  }

  double _calculateDiodeScoringPower(String material, double thickness) {
    return (_calculateDiodeCuttingPower(material, thickness) * 0.7).clamp(
      10,
      100,
    );
  }

  double _calculateDiodeScoringSpeed(String material, double thickness) {
    return (_calculateDiodeCuttingSpeed(material, thickness) + 50).clamp(
      80,
      500,
    );
  }

  int _calculateDiodePasses(double thickness) {
    if (thickness <= 2) return 2;
    if (thickness <= 4) return 3;
    if (thickness <= 6) return 4;
    if (thickness <= 8) return 6;
    return 8; // Max for diode
  }

  // Materyal bazlı hesaplama yardımcıları
}
