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

    // Load local tasks first
    final localTasks = await offlineService.getLocalTasks();
    print('TasksController: Loaded ${localTasks.length} local tasks');

    // Listen to Firebase task stream and update state
    firebaseService.getTasks().listen((tasks) async {
      final currentState = state.valueOrNull ?? [];
      final uniqueTasks =
          tasks.where((t) => !currentState.any((s) => s.id == t.id)).toList();
      if (uniqueTasks.isNotEmpty) {
        state = AsyncData([...currentState, ...uniqueTasks]);
        print(
            'TasksController: Added ${uniqueTasks.length} new tasks from Firebase');
      }
    });

    // Merge local and Firebase tasks, preferring local if not synced
    final firebaseTasks = state.valueOrNull ?? [];
    final mergedTasks = [
      ...localTasks.where((t) => !t.isSynced),
      ...firebaseTasks,
      ...localTasks
          .where((t) => t.isSynced && !firebaseTasks.any((f) => f.id == t.id)),
    ].fold<List<TaskModel>>([], (list, task) {
      if (!list.any((t) => t.id == task.id)) {
        list.add(task);
      }
      return list;
    });
    print('TasksController: Merged ${mergedTasks.length} tasks');
    return mergedTasks;
  }

  Future<void> addTask(TaskModel task) async {
    final currentState = state.valueOrNull ?? [];
    if (currentState.any((t) => t.id == task.id)) {
      Fluttertoast.showToast(
        msg: 'Task already exists: ${task.title}',
        toastLength: Toast.LENGTH_SHORT,
      );
      print('TasksController: Blocked duplicate task ${task.id}');
      return;
    }
    state = AsyncData([...currentState, task]);
    print('TasksController: Added task ${task.id} to state');
  }

  Future<void> updateTask(TaskModel task) async {
    state = AsyncData(
        state.valueOrNull?.map((t) => t.id == task.id ? task : t).toList() ??
            []);
    print('TasksController: Updated task ${task.id} in state');
  }

  Future<void> deleteTask(String taskId) async {
    state = AsyncData(
        state.valueOrNull?.where((t) => t.id != taskId).toList() ?? []);
    print('TasksController: Deleted task $taskId from state');
  }

  Future<void> uploadAttachments(String taskId, List<File> files) async {
    await ref.read(kanbanControllerProvider).uploadAttachments(taskId, files);
    print('TasksController: Queued attachments for task $taskId');
  }
}
