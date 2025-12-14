import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/experiment_model.dart';
import '../models/laser_data_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ========== EXPERIMENT İŞLEMLERİ ==========

  /// Experiment ekle (iki fotoğraf ile)
  Future<void> addExperiment(
    ExperimentModel experiment,
    XFile imageFile, {
    XFile? imageFile2,
  }) async {
    try {
      // ✅ Validasyon: Sadece pozitif değerler (0 ve negatif yasak)
      for (var process in experiment.processes.entries) {
        final params = process.value;
        if (params.speed <= 0) {
          throw Exception(
            '${process.key} için hız 0\'dan büyük olmalı (girilen: ${params.speed})',
          );
        }
        if (params.power <= 0) {
          throw Exception(
            '${process.key} için güç 0\'dan büyük olmalı (girilen: ${params.power})',
          );
        }
        if (params.passes < 1) {
          throw Exception(
            '${process.key} için geçiş sayısı en az 1 olmalı (girilen: ${params.passes})',
          );
        }
      }

      // 1. İlk fotoğrafı Storage'a yükle
      String imageUrl = await _uploadImage(imageFile, 'experiments');

      // 2. İkinci fotoğraf varsa yükle
      String imageUrl2 = '';
      if (imageFile2 != null) {
        imageUrl2 = await _uploadImage(imageFile2, 'experiments');
      }

      // 3. Experiment'i photoUrl'ler ile güncelle
      ExperimentModel updatedExperiment = experiment.copyWith(
        photoUrl: imageUrl,
        photoUrl2: imageUrl2,
      );

      // 4. Firestore'a kaydet
      await _firestore
          .collection('experiments')
          .add(updatedExperiment.toFirestore());
    } catch (e) {
      print('addExperiment hatası: $e');
      rethrow;
    }
  }

  /// Experiment ekle (fotoğraf OLMADAN - harici veri import için)
  Future<void> addExperimentWithoutImage(ExperimentModel experiment) async {
    try {
      await _firestore.collection('experiments').add(experiment.toFirestore());
    } catch (e) {
      print('addExperimentWithoutImage hatası: $e');
      rethrow;
    }
  }

  /// Tüm experiments'leri getir
  Stream<List<ExperimentModel>> getExperiments() {
    return _firestore
        .collection('experiments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ExperimentModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Kullanıcıya ait experiments'leri getir
  Stream<List<ExperimentModel>> getUserExperiments(String userId) {
    return _firestore
        .collection('experiments')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ExperimentModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Araştırmacının eklediği verileri getir
  Stream<List<ExperimentModel>> getResearcherExperiments(String userId) {
    return _firestore
        .collection('experiments')
        .where('userId', isEqualTo: userId)
        .where('dataSource', whereIn: ['researcher', 'researcher_import'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ExperimentModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Tek bir experiment'in stream'ini getir
  Stream<DocumentSnapshot> getExperimentStream(String experimentId) {
    return _firestore.collection('experiments').doc(experimentId).snapshots();
  }

  // ========== LASER DATA İŞLEMLERİ ==========

  Future<void> addLaserData(LaserDataModel laserData, XFile imageFile) async {
    try {
      String imageUrl = await _uploadImage(imageFile, 'laser_data');
      LaserDataModel updatedData = laserData.copyWith(imageUrl: imageUrl);
      await _firestore.collection('laser_data').add(updatedData.toFirestore());
    } catch (e) {
      print('addLaserData hatası: $e');
      rethrow;
    }
  }

  Stream<List<LaserDataModel>> getLaserData() {
    return _firestore
        .collection('laser_data')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => LaserDataModel.fromFirestore(doc))
              .toList();
        });
  }

  Stream<List<LaserDataModel>> getGoldStandardData() {
    return _firestore
        .collection('laser_data')
        .where('isGoldStandard', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => LaserDataModel.fromFirestore(doc))
              .toList();
        });
  }

  // ========== YARDIMCI METODLAR ==========

  Future<String> _uploadImage(XFile imageFile, String folder) async {
    try {
      String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';
      Reference ref = _storage.ref().child('$folder/$fileName');

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'Access-Control-Allow-Origin': '*'},
      );

      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        await ref.putData(bytes, metadata);
      } else {
        await ref.putFile(File(imageFile.path), metadata);
      }

      String downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('_uploadImage hatası: $e');
      rethrow;
    }
  }

  Future<void> updateUserReputation(String userId, int reputationChange) async {
    try {
      DocumentReference userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>?;

      if (userData == null || !userData.containsKey('reputation')) {
        await userRef.set({
          'reputation': reputationChange,
        }, SetOptions(merge: true));
      } else {
        await userRef.update({
          'reputation': FieldValue.increment(reputationChange),
        });
      }
    } catch (e) {
      print('updateUserReputation hatası: $e');
      rethrow;
    }
  }

  Future<void> voteExperiment(String experimentId, bool isUpvote) async {
    try {
      DocumentReference experimentRef = _firestore
          .collection('experiments')
          .doc(experimentId);
      String field = isUpvote ? 'upvotes' : 'downvotes';
      await experimentRef.update({field: FieldValue.increment(1)});
    } catch (e) {
      print('voteExperiment hatası: $e');
      rethrow;
    }
  }

  Future<void> voteLaserData(String dataId, bool isUpvote) async {
    try {
      DocumentReference dataRef = _firestore
          .collection('laser_data')
          .doc(dataId);
      String field = isUpvote ? 'upvotes' : 'downvotes';
      await dataRef.update({field: FieldValue.increment(1)});
    } catch (e) {
      print('voteLaserData hatası: $e');
      rethrow;
    }
  }

  Stream<List<ExperimentModel>> getExperimentsByStatus(String status) {
    return _firestore
        .collection('experiments')
        .where('verificationStatus', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ExperimentModel.fromFirestore(doc))
              .toList();
        });
  }

  Stream<List<ExperimentModel>> getExperimentsByDataSource(String dataSource) {
    return _firestore
        .collection('experiments')
        .where('dataSource', isEqualTo: dataSource)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ExperimentModel.fromFirestore(doc))
              .toList();
        });
  }

  Stream<List<ExperimentModel>> getExperimentsByStatusAndSource(
    String status,
    String dataSource,
  ) {
    return _firestore
        .collection('experiments')
        .where('verificationStatus', isEqualTo: status)
        .where('dataSource', isEqualTo: dataSource)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ExperimentModel.fromFirestore(doc))
              .toList();
        });
  }

  Future<Map<String, dynamic>> getUserVoteStatus(
    String experimentId,
    String userId,
  ) async {
    try {
      final voteQuery =
          await _firestore
              .collection('experiment_votes')
              .where('experimentId', isEqualTo: experimentId)
              .where('userId', isEqualTo: userId)
              .limit(1)
              .get();

      if (voteQuery.docs.isEmpty) {
        return {'hasVoted': false, 'isApprove': null};
      }

      final voteData = voteQuery.docs.first.data();
      return {'hasVoted': true, 'isApprove': voteData['isApprove'] as bool};
    } catch (e) {
      return {'hasVoted': false, 'isApprove': null};
    }
  }

  Future<void> voteOnExperiment(
    String experimentId,
    String userId,
    bool isApprove,
  ) async {
    try {
      final existingVote =
          await _firestore
              .collection('experiment_votes')
              .where('experimentId', isEqualTo: experimentId)
              .where('userId', isEqualTo: userId)
              .limit(1)
              .get();

      if (existingVote.docs.isNotEmpty) {
        throw Exception('Bu deneye zaten oy kullandınız!');
      }

      await _firestore.collection('experiment_votes').add({
        'experimentId': experimentId,
        'userId': userId,
        'isApprove': isApprove,
        'votedAt': Timestamp.now(),
      });

      await _updateExperimentStatus(experimentId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> changeExperimentVote(
    String experimentId,
    String userId,
    bool newVoteChoice,
  ) async {
    try {
      final existingVote =
          await _firestore
              .collection('experiment_votes')
              .where('experimentId', isEqualTo: experimentId)
              .where('userId', isEqualTo: userId)
              .limit(1)
              .get();

      if (existingVote.docs.isEmpty) {
        throw Exception('Değiştirilecek oy bulunamadı!');
      }

      await _firestore
          .collection('experiment_votes')
          .doc(existingVote.docs.first.id)
          .update({'isApprove': newVoteChoice, 'updatedAt': Timestamp.now()});

      await _updateExperimentStatus(experimentId);
    } catch (e) {
      rethrow;
    }
  }

  // ✅ GELİŞTİRİLMİŞ OYLAMA SİSTEMİ
  Future<void> _updateExperimentStatus(String experimentId) async {
    try {
      // 1. Tüm oyları say
      final votes =
          await _firestore
              .collection('experiment_votes')
              .where('experimentId', isEqualTo: experimentId)
              .get();

      int approveCount = 0;
      int rejectCount = 0;

      for (var vote in votes.docs) {
        if (vote.data()['isApprove'] == true) {
          approveCount++;
        } else {
          rejectCount++;
        }
      }

      final totalVotes = approveCount + rejectCount;

      // 2. Experiment'i al
      final experimentDoc =
          await _firestore.collection('experiments').doc(experimentId).get();
      if (!experimentDoc.exists) return;

      final experimentData = experimentDoc.data() as Map<String, dynamic>;
      final currentStatus = experimentData['verificationStatus'] as String;
      final experimentUserId = experimentData['userId'] as String;

      // ✅ SEÇENEk 1 (MODIFIYE): REJECTED OLAN VERIFIED OLAMAZ
      // Rejected bir veri artık asla verified olamaz (kesin red)
      // Ama verified bir veri rejected olabilir (topluluk değişikliği)
      if (currentStatus == 'rejected') {
        // Sadece oy sayılarını güncelle, rejected'dan dönüş yok
        await _firestore.collection('experiments').doc(experimentId).update({
          'approveCount': approveCount,
          'rejectCount': rejectCount,
        });
        return; // Rejected kesin, değişmez
      }

      // 3. ✅ YENİ KURALLAR (Pending ve Verified için)
      String newStatus = 'pending';

      // Kural 1: 5 onay = verified (geçici - red kontrolü yapılacak)
      if (approveCount >= 5) {
        newStatus = 'verified';
      }

      // Kural 2: Red sayısı toplam oyun %50'sini geçerse rejected
      // Bu kural 5 onay olsa bile geçerli!
      // Örnek: 5 onay + 6 red = 11 oy, %54.5 red → REJECTED
      // Örnek: 5 onay + 5 red = 10 oy, %50 red → VERIFIED (eşitlik)
      if (totalVotes >= 3 && rejectCount > 0) {
        final rejectPercentage = (rejectCount / totalVotes) * 100;

        // %50'den fazla red varsa rejected (5 onay olsa bile!)
        if (rejectPercentage > 50.0) {
          newStatus = 'rejected';
        }
      }

      // 4. Status değiştiyse güncelle
      if (currentStatus != newStatus) {
        await _firestore.collection('experiments').doc(experimentId).update({
          'verificationStatus': newStatus,
          'approveCount': approveCount,
          'rejectCount': rejectCount,
        });

        // 5. Reputation güncelle
        if (newStatus == 'verified' && currentStatus != 'verified') {
          // Verified oldu → +10 puan
          await updateUserReputation(experimentUserId, 10);
        }
        if (currentStatus == 'verified' && newStatus != 'verified') {
          // Verified'dan düştü → -10 puan
          await updateUserReputation(experimentUserId, -10);
        }
        if (newStatus == 'rejected' && currentStatus != 'rejected') {
          // Rejected oldu → -5 puan
          await updateUserReputation(experimentUserId, -5);
        }
      } else {
        // Status değişmedi, sadece sayıları güncelle
        await _firestore.collection('experiments').doc(experimentId).update({
          'approveCount': approveCount,
          'rejectCount': rejectCount,
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ExperimentModel>> getFilteredExperiments({
    String? materialType,
    double? minLaserPower,
    double? maxLaserPower,
    String? machineBrand,
  }) async {
    try {
      Query query = _firestore.collection('experiments');

      if (materialType != null && materialType.isNotEmpty) {
        query = query.where('materialType', isEqualTo: materialType);
      }
      if (machineBrand != null && machineBrand.isNotEmpty) {
        query = query.where('machineBrand', isEqualTo: machineBrand);
      }

      QuerySnapshot snapshot = await query.get();
      List<ExperimentModel> experiments =
          snapshot.docs
              .map((doc) => ExperimentModel.fromFirestore(doc))
              .toList();

      if (minLaserPower != null) {
        experiments =
            experiments
                .where((exp) => exp.laserPower >= minLaserPower)
                .toList();
      }
      if (maxLaserPower != null) {
        experiments =
            experiments
                .where((exp) => exp.laserPower <= maxLaserPower)
                .toList();
      }

      return experiments;
    } catch (e) {
      rethrow;
    }
  }
}
