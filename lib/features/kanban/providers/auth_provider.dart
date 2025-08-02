import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_board/features/kanban/providers/kanban_provider.dart';
import '../../core/services/firebase_service.dart';
import '../controllers/auth_controller.dart';

final authControllerProvider = Provider((ref) {
  return AuthController(ref.read(firebaseServiceProvider));
});

final authStateProvider = StreamProvider((ref) {
  return ref.read(firebaseServiceProvider).authStateChanges;
});
