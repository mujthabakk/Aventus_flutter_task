// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../models/task_model.dart';

// class FirebaseService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;

//   String? get currentUserId => _auth.currentUser?.uid;

//   Future<void> signIn(String email, String password) async {
//     await _auth.signInWithEmailAndPassword(email: email, password: password);
//   }

//   Future<void> signUp(String email, String password) async {
//     await _auth.createUserWithEmailAndPassword(
//         email: email, password: password);
//   }

//   Stream<List<TaskModel>> getTasks() {
//     return _firestore.collection('tasks').snapshots().map((snapshot) => snapshot
//         .docs
//         .map((doc) => TaskModel.fromJson(doc.data()..['id'] = doc.id))
//         .toList());
//   }

//   Future<void> addTask(TaskModel task) async {
//     await _firestore.collection('tasks').doc(task.id).set(task.toJson());
//   }

//   Future<void> updateTask(TaskModel task) async {
//     final docRef = _firestore.collection('tasks').doc(task.id);
//     final existingDoc = await docRef.get();
//     if (existingDoc.exists) {
//       final existingTask = TaskModel.fromJson(existingDoc.data()!);
//       if (task.updatedAt.isBefore(existingTask.updatedAt)) {
//         final mergedTask = _mergeTasks(existingTask, task);
//         await docRef.set(mergedTask.toJson());
//       } else {
//         await docRef.set(task.toJson());
//       }
//     }
//   }

//   Future<void> deleteTask(String taskId) async {
//     await _firestore.collection('tasks').doc(taskId).delete();
//   }

//   TaskModel _mergeTasks(TaskModel serverTask, TaskModel localTask) {
//     final mergedJson = {...serverTask.toJson(), ...localTask.toJson()};
//     return TaskModel.fromJson(mergedJson);
//   }
// }
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:kanban_board/features/core/services/firebase_service.dart';
import 'package:kanban_board/features/kanban/controllers/kanban_controller.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/offline_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/models/task_model.dart';

final firebaseServiceProvider =
    Provider<FirebaseService>((ref) => FirebaseService());
final offlineServiceProvider =
    Provider<OfflineService>((ref) => OfflineService());
final storageServiceProvider =
    Provider<StorageService>((ref) => StorageService());

final kanbanControllerProvider = Provider<KanbanController>((ref) {
  return KanbanController(
    ref.read(firebaseServiceProvider),
    ref.read(offlineServiceProvider),
    ref.read(storageServiceProvider),
    ref,
  );
});

final tasksProvider =
    StateNotifierProvider<TasksNotifier, List<TaskModel>>((ref) {
  return TasksNotifier(ref);
});

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, String>((ref) {
  return NotificationNotifier();
});

class NotificationNotifier extends StateNotifier<String> {
  NotificationNotifier() : super('');

  void setNotification(String message) {
    state = message;
    Fluttertoast.showToast(msg: message);
  }

  void clear() {
    state = '';
  }
}

class TasksNotifier extends StateNotifier<List<TaskModel>> {
  final Ref _ref;

  TasksNotifier(this._ref) : super([]) {
    _init();
  }

  Future<void> _init() async {
    final firebaseService = _ref.read(firebaseServiceProvider);
    final offlineService = _ref.read(offlineServiceProvider);
    firebaseService.getTasks().listen((tasks) {
      state = tasks;
      _checkForConflicts(tasks);
    });
    final localTasks = await offlineService.getLocalTasks();
    state = [
      ...state,
      ...localTasks.where((t) => !state.any((s) => s.id == t.id))
    ];
  }

  void _checkForConflicts(List<TaskModel> serverTasks) {
    final localTasks = state.where((t) => !t.isSynced).toList();
    for (var localTask in localTasks) {
      final serverTask = serverTasks.firstWhere((t) => t.id == localTask.id,
          orElse: () => localTask);
      if (serverTask.updatedAt.isAfter(localTask.updatedAt)) {
        _ref.read(notificationProvider.notifier).setNotification(
              'Conflict resolved for task "${localTask.title}": Server changes applied.',
            );
      }
    }
  }

  void addTask(TaskModel task) {
    state = [...state, task];
    _ref.read(kanbanControllerProvider).addTask(task);
  }

  void updateTask(TaskModel task) {
    state = state.map((t) => t.id == task.id ? task : t).toList();
    _ref.read(kanbanControllerProvider).updateTask(task);
  }

  void deleteTask(String taskId) {
    state = state.where((t) => t.id != taskId).toList();
    _ref.read(kanbanControllerProvider).deleteTask(taskId);
  }

  void uploadAttachments(String taskId, List<File> files) {
    _ref.read(kanbanControllerProvider).uploadAttachments(taskId, files);
  }
}
