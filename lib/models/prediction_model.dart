import 'package:flutter/material.dart';
import 'package:lasertuner/models/experiment_model.dart';

class PredictionRequest {
  final String machineBrand;
  final double laserPower;
  final String materialType;
  final double materialThickness;
  final List<String> processes;

  PredictionRequest({
    required this.machineBrand,
    required this.laserPower,
    required this.materialType,
    required this.materialThickness,
    required this.processes,
  });

  Map<String, dynamic> toMap() {
    return {
      'machineBrand': machineBrand,
      'laserPower': laserPower,
      'materialType': materialType,
      'materialThickness': materialThickness,
      'processes': processes,
    };
  }

  factory PredictionRequest.fromMap(Map<String, dynamic> map) {
    return PredictionRequest(
      machineBrand: map['machineBrand'] ?? '',
      laserPower: (map['laserPower'] ?? 0).toDouble(),
      materialType: map['materialType'] ?? '',
      materialThickness: (map['materialThickness'] ?? 0).toDouble(),
      processes: List<String>.from(map['processes'] ?? []),
    );
  }
}

class PredictionResponse {
  final Map<String, ProcessParams> predictions;
  final double confidenceScore;
  final String notes;
  final int dataPointsUsed;
  final String dataSource;
  final List<String> warnings; // âœ… YENÄ°

  PredictionResponse({
    required this.predictions,
    required this.confidenceScore,
    required this.notes,
    required this.dataPointsUsed,
    required this.dataSource,
    this.warnings = const [], // âœ… YENÄ°
  });

  factory PredictionResponse.fromMap(Map<String, dynamic> map) {
    Map<String, ProcessParams> predictions = {};

    if (map['predictions'] != null) {
      (map['predictions'] as Map<String, dynamic>).forEach((key, value) {
        predictions[key] = ProcessParams.fromMap(value as Map<String, dynamic>);
      });
    }

    return PredictionResponse(
      predictions: predictions,
      confidenceScore: (map['confidenceScore'] ?? 0).toDouble(),
      notes: map['notes'] ?? '',
      dataPointsUsed: map['dataPointsUsed'] ?? 0,
      dataSource: map['dataSource'] ?? 'static_algorithm',
      warnings: List<String>.from(map['warnings'] ?? []), // âœ… YENÄ°
    );
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> predictionsMap = {};
    predictions.forEach((key, value) {
      predictionsMap[key] = value.toMap();
    });

    return {
      'predictions': predictionsMap,
      'confidenceScore': confidenceScore,
      'notes': notes,
      'dataPointsUsed': dataPointsUsed,
      'dataSource': dataSource,
      'warnings': warnings, // âœ… YENÄ°
    };
  }

  // âœ… YENÄ°: Veri kaynaÄŸÄ±na gÃ¶re ikon
  IconData getDataSourceIcon() {
    switch (dataSource) {
      case 'transfer_learning': // Backend'den gelen deÄŸer
        return Icons.psychology;
      case 'static_algorithm':
        return Icons.calculate;
      case 'gemini_ai':
        return Icons.auto_awesome;
      case 'fallback': // Backend'den gelen deÄŸer
        return Icons.engineering;
      default:
        return Icons.info;
    }
  }

  // âœ… YENÄ°: Veri kaynaÄŸÄ±na gÃ¶re renk
  Color getDataSourceColor() {
    switch (dataSource) {
      case 'transfer_learning':
        return Colors.purple;
      case 'static_algorithm':
        return Colors.grey;
      case 'gemini_ai':
        return Colors.blue;
      case 'fallback':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // âœ… GÃœNCELLENDÄ°: Veri kaynaÄŸÄ±na gÃ¶re aÃ§Ä±klama
  String getDataSourceDescription() {
    switch (dataSource) {
      case 'transfer_learning':
        return 'ðŸ¤– Transfer learning model (Firebase verisi ile eÄŸitildi)';
      case 'static_algorithm':
        return 'âš™ï¸ Statik algoritma (Model henÃ¼z eÄŸitilmedi veya yeterli veri yok)';
      case 'gemini_ai':
        return 'ðŸŒŸ Gemini AI ile tahmin edildi';
      case 'fallback':
        return 'âš ï¸ Fallback algoritma (API geÃ§ici olarak kullanÄ±lamÄ±yor)';
      default:
        return 'ðŸ“Š Tahmin tamamlandÄ±';
    }
  }

  // âœ… YENÄ°: GÃ¼venilirlik seviyesi
  String getConfidenceLevel() {
    if (confidenceScore >= 0.80) {
      return 'YÃ¼ksek GÃ¼venilirlik';
    } else if (confidenceScore >= 0.65) {
      return 'Orta GÃ¼venilirlik';
    } else {
      return 'DÃ¼ÅŸÃ¼k GÃ¼venilirlik';
    }
  }

  // âœ… YENÄ°: GÃ¼venilirlik rengi
  Color getConfidenceColor() {
    if (confidenceScore >= 0.80) {
      return Colors.green;
    } else if (confidenceScore >= 0.65) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  // âœ… YENÄ°: Veri kaynaÄŸÄ± Ã¶ncelik sÄ±rasÄ± (karÅŸÄ±laÅŸtÄ±rma iÃ§in)
  int getDataSourcePriority() {
    switch (dataSource) {
      case 'transfer_learning':
        return 1; // En yÃ¼ksek Ã¶ncelik
      case 'gemini_ai':
        return 2;
      case 'static_algorithm':
        return 3;
      case 'fallback':
        return 4; // En dÃ¼ÅŸÃ¼k Ã¶ncelik
      default:
        return 5;
    }
  }

  // âœ… YENÄ°: Veri kaynaÄŸÄ± gÃ¼venilir mi?
  bool isReliableSource() {
    return dataSource == 'transfer_learning' || dataSource == 'gemini_ai';
  }

  // âœ… YENÄ°: UyarÄ± var mÄ±?
  bool hasWarnings() {
    return warnings.isNotEmpty;
  }

  // âœ… YENÄ°: Kritik uyarÄ± var mÄ±? (âš ï¸ ile baÅŸlayan)
  bool hasCriticalWarnings() {
    return warnings.any((warning) => warning.startsWith('âš ï¸'));
  }
}

// API saÄŸlÄ±k durumu
class ApiHealthStatus {
  final bool isHealthy;
  final String? errorMessage;
  final DateTime checkTime;
  final Map<String, dynamic>? details;
  final bool firebaseConnected;
  final int totalExperiments;
  final bool transferLearningEnabled; // âœ… YENÄ°
  final bool transferLearningTrained; // âœ… YENÄ°

  ApiHealthStatus({
    required this.isHealthy,
    this.errorMessage,
    required this.checkTime,
    this.details,
    this.firebaseConnected = false,
    this.totalExperiments = 0,
    this.transferLearningEnabled = false, // âœ… YENÄ°
    this.transferLearningTrained = false, // âœ… YENÄ°
  });

  factory ApiHealthStatus.fromMap(Map<String, dynamic> map) {
    return ApiHealthStatus(
      isHealthy: map['status'] == 'healthy',
      checkTime: DateTime.now(),
      details: map,
      firebaseConnected: map['firebase_status'] == 'connected',
      totalExperiments: map['total_experiments'] ?? 0,
      transferLearningEnabled:
          map['transfer_learning_enabled'] ?? false, // âœ… YENÄ°
      transferLearningTrained:
          map['transfer_learning_trained'] ?? false, // âœ… YENÄ°
    );
  }

  // âœ… YENÄ°: Model durumu mesajÄ±
  String getModelStatusMessage() {
    if (!transferLearningEnabled) {
      return 'Transfer Learning kapalÄ±';
    }
    if (transferLearningTrained) {
      return 'Model eÄŸitildi ve aktif';
    }
    if (totalExperiments < 50) {
      return 'Model eÄŸitimi iÃ§in $totalExperiments/50 deney mevcut';
    }
    return 'Model eÄŸitiliyor...';
  }

  // âœ… YENÄ°: Model durumu ikonu
  IconData getModelStatusIcon() {
    if (!transferLearningEnabled) {
      return Icons.cloud_off;
    }
    if (transferLearningTrained) {
      return Icons.check_circle;
    }
    return Icons.pending;
  }

  // âœ… YENÄ°: Model durumu rengi
  Color getModelStatusColor() {
    if (!transferLearningEnabled) {
      return Colors.grey;
    }
    if (transferLearningTrained) {
      return Colors.green;
    }
    return Colors.orange;
  }
}

// Ä°statistikler
class MLStatistics {
  final int totalDataPoints;
  final int verifiedDataPoints;
  final Map<String, int> materials;
  final Map<String, int> machines;
  final List<String> modelsAvailable;
  final bool firebaseAvailable;

  MLStatistics({
    required this.totalDataPoints,
    required this.verifiedDataPoints,
    required this.materials,
    required this.machines,
    required this.modelsAvailable,
    required this.firebaseAvailable,
  });

  factory MLStatistics.fromMap(Map<String, dynamic> map) {
    return MLStatistics(
      totalDataPoints: map['total_experiments'] ?? 0,
      verifiedDataPoints: map['verified_experiments'] ?? 0,
      materials: Map<String, int>.from(map['materials'] ?? {}),
      machines: Map<String, int>.from(map['machines'] ?? {}),
      modelsAvailable: List<String>.from(map['models_available'] ?? []),
      firebaseAvailable: map['available'] ?? false,
    );
  }

  // âœ… YENÄ°: En popÃ¼ler malzeme
  String? getMostPopularMaterial() {
    if (materials.isEmpty) return null;
    return materials.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  // âœ… YENÄ°: En popÃ¼ler makine
  String? getMostPopularMachine() {
    if (machines.isEmpty) return null;
    return machines.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  // âœ… YENÄ°: Veri kalitesi yÃ¼zdesi
  double getDataQualityPercentage() {
    if (totalDataPoints == 0) return 0.0;
    return (verifiedDataPoints / totalDataPoints) * 100;
  }
}
