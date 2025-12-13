import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lasertuner/models/experiment_model.dart';
import '../models/prediction_model.dart';
import '../config/app_config.dart'; 
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

  /// ✅ YENİ: Detaylı API sağlık durumu
  Future<ApiHealthStatus?> getHealthStatus() async {
    try {
      print('🔍 Fetching detailed health status: $API_URL/health');

      final response = await http
          .get(Uri.parse('$API_URL/health'))
          .timeout(connectionTimeout);

      print('✅ Health status response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiHealthStatus.fromMap(data);
      }
      return null;
    } catch (e) {
      print('❌ Health status fetch failed: $e');
      return null;
    }
  }

  /// ✅ YENİ: Model durumunu getir (eğitildi mi, kaç deney var?)
  Future<Map<String, dynamic>?> getModelStatus() async {
    try {
      print('📊 Fetching model status from: $API_URL/test');

      final response = await http
          .get(Uri.parse('$API_URL/test'))
          .timeout(connectionTimeout);

      print('✅ Model status response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📊 Model Status Data: $data');
        return data;
      }
      return null;
    } catch (e) {
      print('❌ Model status fetch error: $e');
      return null;
    }
  }

  /// İstatistikleri getir
  Future<Map<String, dynamic>?> getStatistics() async {
    try {
      print('📊 Fetching statistics from: $API_URL/statistics');

      final response = await http
          .get(Uri.parse('$API_URL/statistics'))
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ Statistics fetch error: $e');
      return null;
    }
  }

  /// Tahmin al
   Future<PredictionResponse> getPrediction(PredictionRequest request) async {
    try {
      print('📤 Sending prediction request to: $API_URL/predict');
      
      // ✅ Material name'i backend-safe format'a çevir
      final backendMaterial = AppConfig.getMaterialBackendKey(request.materialType);
      
      print('🔄 Material normalized: ${request.materialType} → $backendMaterial');
      
      // ✅ Request body'yi normalize edilmiş material ile oluştur
      final requestBody = {
        'machineBrand': request.machineBrand,
        'laserPower': request.laserPower,
        'materialType': backendMaterial, // ✅ Normalized version
        'materialThickness': request.materialThickness,
        'processes': request.processes,
      };
      
      print('📦 Request data: ${jsonEncode(requestBody)}');

      final response = await http
          .post(
            Uri.parse('$API_URL/predict'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(requestBody),
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
        
        // ✅ Hata mesajını parse et
        String errorMessage = 'Geçersiz veri';
        if (errorData['detail'] is List) {
          final errors = errorData['detail'] as List;
          errorMessage = errors.map((e) => e['msg'] ?? e.toString()).join('\n');
        } else if (errorData['detail'] is String) {
          errorMessage = errorData['detail'];
        }
        
        throw Exception('Validation Error: $errorMessage');
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

  /// ✅ YENİ: Model storage bilgilerini getir
  Future<Map<String, dynamic>?> getModelStorageInfo() async {
    try {
      print('🗄️ Fetching model storage info from: $API_URL/test');

      final response = await http
          .get(Uri.parse('$API_URL/test'))
          .timeout(connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Model storage bilgisi varsa döndür
        if (data['model_storage'] != null) {
          return data['model_storage'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('❌ Model storage info fetch error: $e');
      return null;
    }
  }

  /// ✅ YENİ: API'nin tüm yeteneklerini kontrol et
  Future<Map<String, bool>> checkApiCapabilities() async {
    try {
      final testResponse = await http
          .get(Uri.parse('$API_URL/test'))
          .timeout(connectionTimeout);

      if (testResponse.statusCode == 200) {
        final data = jsonDecode(testResponse.body);

        return {
          'transfer_learning_enabled':
              data['transfer_learning_enabled'] ?? false,
          'transfer_learning_trained':
              data['transfer_learning_trained'] ?? false,
          'firebase_firestore_connected':
              data['firebase_firestore_connected'] ?? false,
          'firebase_storage_connected':
              data['firebase_storage_connected'] ?? false,
        };
      }

      return {
        'transfer_learning_enabled': false,
        'transfer_learning_trained': false,
        'firebase_firestore_connected': false,
        'firebase_storage_connected': false,
      };
    } catch (e) {
      print('❌ API capabilities check error: $e');
      return {
        'transfer_learning_enabled': false,
        'transfer_learning_trained': false,
        'firebase_firestore_connected': false,
        'firebase_storage_connected': false,
      };
    }
  }

  /// ✅ YENİ: Detaylı sistem durumu raporu
  Future<Map<String, dynamic>> getSystemStatusReport() async {
    try {
      final healthStatus = await getHealthStatus();
      final capabilities = await checkApiCapabilities();
      final storageInfo = await getModelStorageInfo();

      return {
        'timestamp': DateTime.now().toIso8601String(),
        'api_online': healthStatus?.isHealthy ?? false,
        'firebase_connected': healthStatus?.firebaseConnected ?? false,
        'total_experiments': healthStatus?.totalExperiments ?? 0,
        'transfer_learning_enabled': capabilities['transfer_learning_enabled'],
        'transfer_learning_trained': capabilities['transfer_learning_trained'],
        'model_in_storage': storageInfo?['exists_in_storage'] ?? false,
        'model_size_mb': storageInfo?['size_mb'] ?? 0.0,
        'capabilities': capabilities,
      };
    } catch (e) {
      print('❌ System status report error: $e');
      return {
        'timestamp': DateTime.now().toIso8601String(),
        'api_online': false,
        'error': e.toString(),
      };
    }
  }

  PredictionResponse generateFallbackPrediction(PredictionRequest request) {
    print('⚠️ Using DIODE LASER fallback prediction algorithm');

    Map<String, ProcessParams> predictions = {};
    double thickness = request.materialThickness;
    List<String> warnings = [];

    // ✅ Material'i normalize et
    final normalizedMaterial = AppConfig.getMaterialBackendKey(request.materialType);

    // Kalınlık uyarısı
    if (thickness > 8) {
      warnings.add(
        '⚠️ ${thickness}mm kalınlık diode lazer için çok zorlu olabilir',
      );
    } else if (thickness > 5) {
      warnings.add('⚠️ ${thickness}mm kalınlık için dikkatli yaklaşın');
    }

    // Güç uyarısı
    if (request.laserPower < 20 && thickness > 3) {
      warnings.add(
        '⚠️ ${request.laserPower}W güç, ${thickness}mm kalınlık için düşük olabilir',
      );
    }

    for (String processType in request.processes) {
      ProcessParams params;

      switch (processType) {
        case 'cutting':
          params = ProcessParams(
            power: _calculateDiodeCuttingPower(normalizedMaterial, thickness),
            speed: _calculateDiodeCuttingSpeed(normalizedMaterial, thickness),
            passes: _calculateDiodePasses(thickness),
          );
          break;
        case 'engraving':
          params = ProcessParams(
            power: _calculateDiodeEngravingPower(normalizedMaterial, thickness),
            speed: _calculateDiodeEngravingSpeed(normalizedMaterial, thickness),
            passes: 1,
          );
          break;
        case 'scoring':
          params = ProcessParams(
            power: _calculateDiodeScoringPower(normalizedMaterial, thickness),
            speed: _calculateDiodeScoringSpeed(normalizedMaterial, thickness),
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
      dataSource: 'fallback',
      warnings: warnings,
    );
  }

  // ========== DIODE LASER HESAPLAMA FONKSİYONLARI ==========

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
      case 'kontrplak':
      case 'plywood':
        basePower = 82;
        multiplier = 4.2;
        break;
      case 'balsa':
        basePower = 60;
        multiplier = 2.5;
        break;
      case 'bambu':
      case 'bamboo':
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
      case 'kece':
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
      case 'akrilik':
      case 'acrylic':
        basePower = 75;
        multiplier = 4.0;
        break;
      case 'lastik':
      case 'rubber':
        basePower = 70;
        multiplier = 3.5;
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
      case 'kontrplak':
      case 'plywood':
        baseSpeed = 290;
        reduction = 32;
        break;
      case 'balsa':
        baseSpeed = 380;
        reduction = 20;
        break;
      case 'bambu':
      case 'bamboo':
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
      case 'kece':
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
      case 'akrilik':
      case 'acrylic':
        baseSpeed = 280;
        reduction = 30;
        break;
      case 'lastik':
      case 'rubber':
        baseSpeed = 350;
        reduction = 28;
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

  // ========== YARDIMCI FONKSİYONLAR ==========

  /// ✅ YENİ: API URL'sini kontrol et
  static bool isValidApiUrl() {
    return API_URL.isNotEmpty &&
        (API_URL.startsWith('http://') || API_URL.startsWith('https://'));
  }

  /// ✅ YENİ: Endpoint oluştur
  static String buildEndpoint(String path) {
    return '$API_URL${path.startsWith('/') ? path : '/$path'}';
  }

  /// ✅ YENİ: Hata mesajını kullanıcı dostu yap
  String getFriendlyErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('timeout')) {
      return 'API sunucusu yanıt vermiyor. İlk istekte soğuk başlangıç yapıyor olabilir. Lütfen 10-15 saniye bekleyip tekrar deneyin.';
    } else if (errorStr.contains('socket') || errorStr.contains('connection')) {
      return 'İnternet bağlantınızı kontrol edin. API sunucusuna erişilemiyor.';
    } else if (errorStr.contains('422')) {
      return 'Gönderilen veri formatı hatalı. Lütfen girilen değerleri kontrol edin.';
    } else if (errorStr.contains('500')) {
      return 'Sunucu hatası oluştu. Lütfen birkaç dakika sonra tekrar deneyin.';
    } else if (errorStr.contains('404')) {
      return 'İstenen API endpoint bulunamadı. Uygulama güncellemesi gerekebilir.';
    }

    return 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
  }
}
