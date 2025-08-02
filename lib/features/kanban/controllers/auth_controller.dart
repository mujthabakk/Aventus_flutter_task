import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/firebase_service.dart';

class AuthController {
  final FirebaseService _firebaseService;

  AuthController(this._firebaseService);

  Future<void> signIn(String email, String password) async {
    await _firebaseService.signIn(email, password);
  }

  Future<void> signUp(String email, String password) async {
    await _firebaseService.signUp(email, password);
  }

  Future<void> signOut() async {
    await _firebaseService.signOut();
  }

  Stream get authStateChanges => _firebaseService.authStateChanges;

  String? get currentUserId => _firebaseService.currentUserId; // Add getter
}
