import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:kanban_board/core/models/task_model.dart';
import 'package:kanban_board/core/services/firebase_service.dart';
import 'package:kanban_board/core/services/offline_service.dart';
import 'package:kanban_board/core/services/storage_service.dart';
import 'package:kanban_board/features/kanban/controllers/kanban_controller.dart';
import 'dart:io';
import 'package:fluttertoast/fluttertoast.dart';

part 'kanban_provider.g.dart';

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

@riverpod
class TasksController extends _$TasksController {
  @override
  FutureOr<List<TaskModel>> build() async {
    final firebaseService = ref.read(firebaseServiceProvider);
    final offlineService = ref.read(offlineServiceProvider);

    // Listen to Firebase task stream and update state
    firebaseService.getTasks().listen((tasks) {
      state = AsyncData(tasks);
      // Sync local tasks with Firebase
      ref.read(kanbanControllerProvider).syncTasks();
    });

    // Fetch local tasks and merge with Firebase tasks
    final localTasks = await offlineService.getLocalTasks();
    final firebaseTasks = state.valueOrNull ?? [];
    return [
      ...firebaseTasks,
      ...localTasks.where((t) => !firebaseTasks.any((s) => s.id == t.id)),
    ];
  }

  Future<void> addTask(TaskModel task) async {
    state = AsyncData([...state.valueOrNull ?? [], task]);
    await ref.read(kanbanControllerProvider).addTask(task);
  }

  Future<void> updateTask(TaskModel task) async {
    state = AsyncData(
        state.valueOrNull?.map((t) => t.id == task.id ? task : t).toList() ??
            []);
    await ref.read(kanbanControllerProvider).updateTask(task);
  }

  Future<void> deleteTask(String taskId) async {
    state = AsyncData(
        state.valueOrNull?.where((t) => t.id != taskId).toList() ?? []);
    await ref.read(kanbanControllerProvider).deleteTask(taskId);
  }

  Future<void> uploadAttachments(String taskId, List<File> files) async {
    await ref.read(kanbanControllerProvider).uploadAttachments(taskId, files);
  }
}
