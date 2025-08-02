import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_board/core/config/constants.dart';
import 'package:kanban_board/utils/extensions.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/offline_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/models/task_model.dart';
import '../providers/kanban_provider.dart';

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
      updatedBy: _firebaseService.currentUserId ?? '',
    );
    await _offlineService.saveTask(newTask, action: 'add');
    await _ref.read(tasksControllerProvider.notifier).addTask(newTask);
    await syncTasks();
  }

  Future<void> updateTask(TaskModel task) async {
    final updatedTask = task.copyWith(
      updatedAt: DateTime.now(),
      updatedBy: _firebaseService.currentUserId ?? '',
    );
    await _offlineService.saveTask(updatedTask, action: 'update');
    await _ref.read(tasksControllerProvider.notifier).updateTask(updatedTask);
    await syncTasks();
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
        updatedBy: _firebaseService.currentUserId ?? '',
      ),
      action: 'delete',
    );
    await _ref.read(tasksControllerProvider.notifier).deleteTask(taskId);
    await syncTasks();
  }

  Future<void> uploadAttachments(String taskId, List<File> files) async {
    for (var file in files) {
      final storagePath =
          '${Constants.attachmentsPath}/$taskId/${file.path.split('/').last}';
      await _offlineService.queueFileUpload(taskId, file, storagePath);
    }
    await syncUploads();
  }

  Future<void> syncTasks() async {
    final tasks = await _offlineService.getLocalTasks();
    for (var task in tasks.where((t) => !t.isSynced)) {
      try {
        if (task.pendingAction == 'add') {
          await _firebaseService.addTask(task);
          await _offlineService.markTaskAsSynced(task.id);
        } else if (task.pendingAction == 'update') {
          final docRef =
              FirebaseFirestore.instance.collection('tasks').doc(task.id);
          final existingDoc = await docRef.get();
          if (existingDoc.exists) {
            final existingTask = TaskModel.fromJson(existingDoc.data()!);
            if (task.updatedAt.isBefore(existingTask.updatedAt)) {
              final mergedTask = _mergeTasks(existingTask, task);
              await docRef.set(mergedTask.toJson());
              await _offlineService.saveTask(mergedTask, action: 'update');
              _showConflictNotification();
            } else {
              await docRef.set(task.toJson());
            }
          } else {
            await docRef.set(task.toJson());
          }
          await _offlineService.markTaskAsSynced(task.id);
        } else if (task.pendingAction == 'delete') {
          await _firebaseService.deleteTask(task.id);
          await _offlineService.deleteLocalTask(task.id);
        }
      } catch (e) {
        Fluttertoast.showToast(
          msg: 'Sync failed for task ${task.title}: $e',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
      }
    }
  }

  Future<void> syncUploads() async {
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
          updatedBy: _firebaseService.currentUserId ?? '',
        );
        await updateTask(updatedTask);
        await _offlineService.clearPendingUpload(
            upload['taskId'], upload['filePath']);
        Fluttertoast.showToast(
          msg: 'File uploaded for task ${task.title}',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      } catch (e) {
        Fluttertoast.showToast(
          msg: 'Upload failed for task ${upload['taskId']}: $e',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
      }
    }
  }

  TaskModel _mergeTasks(TaskModel serverTask, TaskModel localTask) {
    final mergedJson = {...serverTask.toJson(), ...localTask.toJson()};
    final mergedTask = TaskModel.fromJson(mergedJson);
    return mergedTask.copyWith(
      updatedAt: DateTime.now(),
      updatedBy: _firebaseService.currentUserId ?? '',
    );
  }

  void _showConflictNotification() {
    Fluttertoast.showToast(
      msg: 'Conflict detected and resolved by merging changes',
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
    );
  }
}
