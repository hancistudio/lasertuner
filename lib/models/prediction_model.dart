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
  final String dataSource; // ✨ YENİ

  PredictionResponse({
    required this.predictions,
    required this.confidenceScore,
    required this.notes,
    required this.dataPointsUsed,
    required this.dataSource,
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
      dataSource: map['dataSource'] ?? 'static_algorithm', // ✨ YENİ
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
    };
  }

  // ✨ YENİ: Veri kaynağına göre ikon
  IconData getDataSourceIcon() {
    switch (dataSource) {
      case 'user_data':
        return Icons.groups;
      case 'hybrid':
        return Icons.merge_type;
      case 'static_algorithm':
      default:
        return Icons.calculate;
    }
  }

  // ✨ YENİ: Veri kaynağına göre renk
  Color getDataSourceColor() {
    switch (dataSource) {
      case 'user_data':
        return Colors.green;
      case 'hybrid':
        return Colors.orange;
      case 'static_algorithm':
      default:
        return Colors.grey;
    }
  }

  // ✨ YENİ: Veri kaynağına göre açıklama
  String getDataSourceDescription() {
    switch (dataSource) {
      case 'user_data':
        return 'Topluluk verileriyle tahmin edildi';
      case 'hybrid':
        return 'Kısmi topluluk verisi kullanıldı';
      case 'static_algorithm':
      default:
        return 'Temel algoritma ile tahmin edildi';
    }
  }
}

// API sağlık durumu
class ApiHealthStatus {
  final bool isHealthy;
  final String? errorMessage;
  final DateTime checkTime;
  final Map<String, dynamic>? details;
  final bool firebaseConnected;
  final int totalExperiments;

  ApiHealthStatus({
    required this.isHealthy,
    this.errorMessage,
    required this.checkTime,
    this.details,
    this.firebaseConnected = false,
    this.totalExperiments = 0,
  });

  factory ApiHealthStatus.fromMap(Map<String, dynamic> map) {
    return ApiHealthStatus(
      isHealthy: map['status'] == 'healthy',
      checkTime: DateTime.now(),
      details: map,
      firebaseConnected: map['firebase_status'] == 'connected',
      totalExperiments: map['total_experiments'] ?? 0,
    );
  }
}

// İstatistikler
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
}
