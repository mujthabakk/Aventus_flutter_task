import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_board/core/config/constants.dart';
import 'package:kanban_board/features/core/services/firebase_service.dart';
import 'package:kanban_board/utils/extensions.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/offline_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/models/task_model.dart';
import '../providers/kanban_provider.dart' hide tasksProvider;

class KanbanController {
  final FirebaseService _firebaseService;
  final OfflineService _offlineService;
  final StorageService _storageService;
  final ProviderRef _ref;

  KanbanController(this._firebaseService, this._offlineService,
      this._storageService, this._ref);

  Future<void> addTask(TaskModel task) async {
    final newTask = task.copyWith(
      id: const Uuid().v4(),
      updatedAt: DateTime.now(),
      updatedBy: _firebaseService.currentUserId!,
    );
    await _offlineService.saveTask(newTask, action: 'add');
    _ref.read(tasksProvider.notifier).addTask(newTask);
    await _syncTasks();
  }

  Future<void> updateTask(TaskModel task) async {
    final updatedTask = task.copyWith(
      updatedAt: DateTime.now(),
      updatedBy: _firebaseService.currentUserId!,
    );
    await _offlineService.saveTask(updatedTask, action: 'update');
    _ref.read(tasksProvider.notifier).updateTask(updatedTask);
    await _syncTasks();
  }

  Future<void> deleteTask(String taskId) async {
    await _offlineService.saveTask(
      TaskModel(
        id: taskId,
        title: '',
        description: '',
        status: '',
        assignedTo: '',
        updatedAt: DateTime.now(),
        updatedBy: _firebaseService.currentUserId!,
      ),
      action: 'delete',
    );
    _ref.read(tasksProvider.notifier).deleteTask(taskId);
    await _syncTasks();
  }

  Future<void> uploadAttachments(String taskId, List<File> files) async {
    for (var file in files) {
      final storagePath =
          '${Constants.attachmentsPath}/$taskId/${file.path.split('/').last}';
      await _offlineService.queueFileUpload(taskId, file, storagePath);
    }
    await _syncUploads();
  }

  Future<void> _syncTasks() async {
    final tasks = await _offlineService.getLocalTasks();
    for (var task in tasks.where((t) => !t.isSynced)) {
      try {
        if (task.pendingAction == 'add') {
          await _firebaseService.addTask(task);
        } else if (task.pendingAction == 'update') {
          await _firebaseService.updateTask(task);
        } else if (task.pendingAction == 'delete') {
          await _firebaseService.deleteTask(task.id);
        }
        await _offlineService.markTaskAsSynced(task.id);
      } catch (e) {
        // Handle sync failure
      }
    }
  }

  Future<void> _syncUploads() async {
    final uploads = await _offlineService.getPendingUploads();
    for (var upload in uploads) {
      try {
        final file = File(upload['filePath']);
        final url = await _storageService.uploadFile(upload['taskId'], file);
        final task = (await _offlineService.getLocalTasks())
            .firstWhere((t) => t.id == upload['taskId']);
        final updatedTask = task.copyWith(
          attachments: [...task.attachments, url],
          updatedAt: DateTime.now(),
          updatedBy: _firebaseService.currentUserId!,
        );
        await updateTask(updatedTask);
        await _offlineService.clearPendingUpload(
            upload['taskId'], upload['filePath']);
      } catch (e) {
        // Handle upload failure
      }
    }
  }
}
