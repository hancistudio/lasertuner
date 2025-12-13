import 'package:cloud_firestore/cloud_firestore.dart';

class LaserDataModel {
  final String id;
  final String userId;
  final double power;
  final double frequency;
  final double pulseWidth;
  final double spotSize;
  final double fluence;
  final int passes;
  final String skinType;
  final String hairColor;
  final String notes;
  final String? imageUrl;
  final bool isGoldStandard;
  final int upvotes;
  final int downvotes;
  final DateTime createdAt;

  LaserDataModel({
    required this.id,
    required this.userId,
    required this.power,
    required this.frequency,
    required this.pulseWidth,
    required this.spotSize,
    required this.fluence,
    required this.passes,
    required this.skinType,
    required this.hairColor,
    this.notes = '',
    this.imageUrl,
    this.isGoldStandard = false,
    this.upvotes = 0,
    this.downvotes = 0,
    required this.createdAt,
  });

  // âœ… copyWith metodu
  LaserDataModel copyWith({
    String? id,
    String? userId,
    double? power,
    double? frequency,
    double? pulseWidth,
    double? spotSize,
    double? fluence,
    int? passes,
    String? skinType,
    String? hairColor,
    String? notes,
    String? imageUrl,
    bool? isGoldStandard,
    int? upvotes,
    int? downvotes,
    DateTime? createdAt,
  }) {
    return LaserDataModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      power: power ?? this.power,
      frequency: frequency ?? this.frequency,
      pulseWidth: pulseWidth ?? this.pulseWidth,
      spotSize: spotSize ?? this.spotSize,
      fluence: fluence ?? this.fluence,
      passes: passes ?? this.passes,
      skinType: skinType ?? this.skinType,
      hairColor: hairColor ?? this.hairColor,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
      isGoldStandard: isGoldStandard ?? this.isGoldStandard,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Firestore'dan oku
  factory LaserDataModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LaserDataModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      power: (data['power'] ?? 0).toDouble(),
      frequency: (data['frequency'] ?? 0).toDouble(),
      pulseWidth: (data['pulseWidth'] ?? 0).toDouble(),
      spotSize: (data['spotSize'] ?? 0).toDouble(),
      fluence: (data['fluence'] ?? 0).toDouble(),
      passes: data['passes'] ?? 0,
      skinType: data['skinType'] ?? '',
      hairColor: data['hairColor'] ?? '',
      notes: data['notes'] ?? '',
      imageUrl: data['imageUrl'],
      isGoldStandard: data['isGoldStandard'] ?? false,
      upvotes: data['upvotes'] ?? 0,
      downvotes: data['downvotes'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  // Firestore'a yaz
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'power': power,
      'frequency': frequency,
      'pulseWidth': pulseWidth,
      'spotSize': spotSize,
      'fluence': fluence,
      'passes': passes,
      'skinType': skinType,
      'hairColor': hairColor,
      'notes': notes,
      'imageUrl': imageUrl,
      'isGoldStandard': isGoldStandard,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
