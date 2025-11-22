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
  final int? dataPointsUsed;

  PredictionResponse({
    required this.predictions,
    required this.confidenceScore,
    required this.notes,
    this.dataPointsUsed,
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
      dataPointsUsed: map['dataPointsUsed'] as int?,
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
      if (dataPointsUsed != null) 'dataPointsUsed': dataPointsUsed,
    };
  }
}

// API sağlık durumu
class ApiHealthStatus {
  final bool isHealthy;
  final String? errorMessage;
  final DateTime checkTime;
  final Map<String, dynamic>? details;

  ApiHealthStatus({
    required this.isHealthy,
    this.errorMessage,
    required this.checkTime,
    this.details,
  });

  factory ApiHealthStatus.fromMap(Map<String, dynamic> map) {
    return ApiHealthStatus(
      isHealthy: map['status'] == 'healthy',
      checkTime: DateTime.now(),
      details: map,
    );
  }
}

// İstatistikler
class MLStatistics {
  final int totalDataPoints;
  final Map<String, int> materials;
  final Map<String, int> machines;
  final List<String> modelsAvailable;

  MLStatistics({
    required this.totalDataPoints,
    required this.materials,
    required this.machines,
    required this.modelsAvailable,
  });

  factory MLStatistics.fromMap(Map<String, dynamic> map) {
    return MLStatistics(
      totalDataPoints: map['total_data_points'] ?? 0,
      materials: Map<String, int>.from(map['materials'] ?? {}),
      machines: Map<String, int>.from(map['machines'] ?? {}),
      modelsAvailable: List<String>.from(map['models_available'] ?? []),
    );
  }
}
