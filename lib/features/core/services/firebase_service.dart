import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kanban_board/core/models/task_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Stream get authStateChanges => _auth.authStateChanges();

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signUp(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Stream<List<TaskModel>> getTasks() {
    return _firestore.collection('tasks').snapshots().map((snapshot) => snapshot
        .docs
        .map((doc) => TaskModel.fromJson(doc.data()..['id'] = doc.id))
        .toList());
  }

  Future<void> addTask(TaskModel task) async {
    await _firestore.collection('tasks').doc(task.id).set(task.toJson());
  }

  Future<void> updateTask(TaskModel task) async {
    final docRef = _firestore.collection('tasks').doc(task.id);
    final existingDoc = await docRef.get();
    if (existingDoc.exists) {
      final existingTask = TaskModel.fromJson(existingDoc.data()!);
      if (task.updatedAt.isBefore(existingTask.updatedAt)) {
        final mergedTask = _mergeTasks(existingTask, task);
        await docRef.set(mergedTask.toJson());
        return;
      }
    }
    await docRef.set(task.toJson());
  }

  Future<void> deleteTask(String taskId) async {
    await _firestore.collection('tasks').doc(taskId).delete();
  }

  TaskModel _mergeTasks(TaskModel serverTask, TaskModel localTask) {
    final mergedJson = {...serverTask.toJson(), ...localTask.toJson()};
    return TaskModel.fromJson(mergedJson);
  }
} // TODO Implement this library.
