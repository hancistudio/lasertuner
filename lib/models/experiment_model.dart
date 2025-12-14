import 'package:cloud_firestore/cloud_firestore.dart';

class ProcessParams {
  final double power;
  final double speed;
  final int passes;

  ProcessParams({
    required this.power,
    required this.speed,
    required this.passes,
  }) {
    // ✅ Sadece pozitif değerler
    if (power <= 0) {
      throw ArgumentError('Güç 0\'dan büyük olmalı (girilen: $power)');
    }
    if (speed <= 0) {
      throw ArgumentError('Hız 0\'dan büyük olmalı (girilen: $speed)');
    }
    if (passes < 1) {
      throw ArgumentError('Geçiş sayısı en az 1 olmalı (girilen: $passes)');
    }
  }

  Map<String, dynamic> toMap() {
    return {'power': power, 'speed': speed, 'passes': passes};
  }

  factory ProcessParams.fromMap(Map<String, dynamic> map) {
    return ProcessParams(
      power: (map['power'] ?? 0).toDouble(),
      speed: (map['speed'] ?? 0).toDouble(),
      passes: map['passes'] ?? 1,
    );
  }
}

class ExperimentModel {
  final String id;
  final String userId;
  final String machineBrand;
  final double laserPower;
  final String materialType;
  final double materialThickness;
  final Map<String, ProcessParams> processes;
  final String photoUrl;
  final String photoUrl2; // İkinci fotoğraf
  final Map<String, int> qualityScores;
  final String dataSource;
  final String verificationStatus;
  final int approveCount;
  final int rejectCount;
  final DateTime createdAt;

  ExperimentModel({
    required this.id,
    required this.userId,
    required this.machineBrand,
    required this.laserPower,
    required this.materialType,
    required this.materialThickness,
    required this.processes,
    required this.photoUrl,
    this.photoUrl2 = '',
    required this.qualityScores,
    required this.dataSource,
    required this.verificationStatus,
    this.approveCount = 0,
    this.rejectCount = 0,
    required this.createdAt,
  });

  ExperimentModel copyWith({
    String? id,
    String? userId,
    String? machineBrand,
    double? laserPower,
    String? materialType,
    double? materialThickness,
    Map<String, ProcessParams>? processes,
    String? photoUrl,
    String? photoUrl2,
    Map<String, int>? qualityScores,
    String? dataSource,
    String? verificationStatus,
    int? approveCount,
    int? rejectCount,
    DateTime? createdAt,
  }) {
    return ExperimentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      machineBrand: machineBrand ?? this.machineBrand,
      laserPower: laserPower ?? this.laserPower,
      materialType: materialType ?? this.materialType,
      materialThickness: materialThickness ?? this.materialThickness,
      processes: processes ?? this.processes,
      photoUrl: photoUrl ?? this.photoUrl,
      photoUrl2: photoUrl2 ?? this.photoUrl2,
      qualityScores: qualityScores ?? this.qualityScores,
      dataSource: dataSource ?? this.dataSource,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      approveCount: approveCount ?? this.approveCount,
      rejectCount: rejectCount ?? this.rejectCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory ExperimentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    Map<String, ProcessParams> processes = {};
    if (data['processes'] != null) {
      (data['processes'] as Map<String, dynamic>).forEach((key, value) {
        processes[key] = ProcessParams.fromMap(value as Map<String, dynamic>);
      });
    }

    Map<String, int> qualityScores = {};
    if (data['qualityScores'] != null) {
      (data['qualityScores'] as Map<String, dynamic>).forEach((key, value) {
        qualityScores[key] = value as int;
      });
    }

    return ExperimentModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      machineBrand: data['machineBrand'] ?? '',
      laserPower: (data['laserPower'] ?? 0).toDouble(),
      materialType: data['materialType'] ?? '',
      materialThickness: (data['materialThickness'] ?? 0).toDouble(),
      processes: processes,
      photoUrl: data['photoUrl'] ?? '',
      photoUrl2: data['photoUrl2'] ?? '',
      qualityScores: qualityScores,
      dataSource: data['dataSource'] ?? 'user',
      verificationStatus: data['verificationStatus'] ?? 'pending',
      approveCount: data['approveCount'] ?? 0,
      rejectCount: data['rejectCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    Map<String, dynamic> processesMap = {};
    processes.forEach((key, value) {
      processesMap[key] = value.toMap();
    });

    return {
      'userId': userId,
      'machineBrand': machineBrand,
      'laserPower': laserPower,
      'materialType': materialType,
      'materialThickness': materialThickness,
      'processes': processesMap,
      'photoUrl': photoUrl,
      'photoUrl2': photoUrl2,
      'qualityScores': qualityScores,
      'dataSource': dataSource,
      'verificationStatus': verificationStatus,
      'approveCount': approveCount,
      'rejectCount': rejectCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
