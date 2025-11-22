import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Kullanıcı stream
  Stream<User?> get userStream => _auth.authStateChanges();

  // Kayıt ol
  Future<UserModel?> signUp(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user != null) {
        UserModel newUser = UserModel(
          uid: user.uid,
          email: email,
          role: 'user',
          reputation: 0, // Başlangıç reputation'u
          createdAt: DateTime.now(),
        );

        // Firestore'a tam veriyi kaydet
        await _firestore.collection('users').doc(user.uid).set({
          'uid': newUser.uid,
          'email': newUser.email,
          'role': newUser.role,
          'reputation': newUser.reputation,
          'createdAt': Timestamp.fromDate(newUser.createdAt),
        });

        return newUser;
      }
    } catch (e) {
      print('Kayıt hatası: $e');
      rethrow;
    }
    return null;
  }

  // Giriş yap
  Future<UserModel?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user != null) {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();

        if (!doc.exists) {
          // Eğer Firestore'da kullanıcı yoksa (eski kullanıcılar için), oluştur
          UserModel newUser = UserModel(
            uid: user.uid,
            email: email,
            role: 'user',
            reputation: 0,
            createdAt: DateTime.now(),
          );

          await _firestore.collection('users').doc(user.uid).set({
            'uid': newUser.uid,
            'email': newUser.email,
            'role': newUser.role,
            'reputation': newUser.reputation,
            'createdAt': Timestamp.fromDate(newUser.createdAt),
          });

          return newUser;
        }

        final data = doc.data() as Map<String, dynamic>;

        // Reputation field'ı yoksa ekle
        if (!data.containsKey('reputation')) {
          await _firestore.collection('users').doc(user.uid).update({
            'reputation': 0,
          });
          data['reputation'] = 0;
        }

        return UserModel.fromMap(data);
      }
    } catch (e) {
      print('Giriş hatası: $e');
      rethrow;
    }
    return null;
  }

  // Çıkış yap
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Mevcut kullanıcı bilgisi
  Future<UserModel?> getCurrentUser() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;

      // Reputation field'ı yoksa ekle
      if (!data.containsKey('reputation')) {
        await _firestore.collection('users').doc(user.uid).update({
          'reputation': 0,
        });
        data['reputation'] = 0;
      }

      return UserModel.fromMap(data);
    }
    return null;
  }
}
