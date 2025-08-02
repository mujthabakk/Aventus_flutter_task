import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_board/features/core/services/firebase_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/offline_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/models/task_model.dart';
import '../controllers/kanban_controller.dart';

final firebaseServiceProvider = Provider((ref) => FirebaseService());
final offlineServiceProvider = Provider((ref) => OfflineService());
final storageServiceProvider = Provider((ref) => StorageService());

final kanbanControllerProvider = Provider((ref) {
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
    });
    final localTasks = await offlineService.getLocalTasks();
    state = [
      ...state,
      ...localTasks.where((t) => !state.any((s) => s.id == t.id))
    ];
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
