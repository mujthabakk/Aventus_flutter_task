import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/offline_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/models/task_model.dart';
import '../providers/kanban_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Constants {
  static const String attachmentsPath = 'attachments';
  static const int maxFileSizeMB = 10;
}

class KanbanController {
  final FirebaseService _firebaseService;
  final OfflineService _offlineService;
  final StorageService _storageService;
  final ProviderRef _ref;
  final Set<String> _syncedTaskIds =
      {}; // Track synced tasks in current session

  KanbanController(this._firebaseService, this._offlineService,
      this._storageService, this._ref);

  Future<void> addTask(TaskModel task) async {
    if (_firebaseService.currentUserId == null) {
      Fluttertoast.showToast(
        msg: 'User not authenticated. Please sign in to add tasks.',
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }
    final newTask = task.copyWith(
      id: task.id.isEmpty ? const Uuid().v4() : task.id,
      updatedAt: DateTime.now(),
      updatedBy: _firebaseService.currentUserId!,
    );
    try {
      await _offlineService.saveTask(newTask, action: 'add');
      await _ref.read(tasksControllerProvider.notifier).addTask(newTask);
      Fluttertoast.showToast(
        msg: 'Task ${newTask.title} added',
        toastLength: Toast.LENGTH_SHORT,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to add task: $e',
        toastLength: Toast.LENGTH_LONG,
      );
      print('Error adding task ${newTask.id}: $e');
    }
  }

  Future<void> updateTask(TaskModel task) async {
    if (_firebaseService.currentUserId == null) {
      Fluttertoast.showToast(
        msg: 'User not authenticated. Please sign in to update tasks.',
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }
    final updatedTask = task.copyWith(
      updatedAt: DateTime.now(),
      updatedBy: _firebaseService.currentUserId!,
    );
    try {
      await _offlineService.saveTask(updatedTask, action: 'update');
      await _ref.read(tasksControllerProvider.notifier).updateTask(updatedTask);
      Fluttertoast.showToast(
        msg: 'Task ${updatedTask.title} updated',
        toastLength: Toast.LENGTH_SHORT,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to update task: $e',
        toastLength: Toast.LENGTH_LONG,
      );
      print('Error updating task ${updatedTask.id}: $e');
    }
  }

  Future<void> deleteTask(String taskId) async {
    if (_firebaseService.currentUserId == null) {
      Fluttertoast.showToast(
        msg: 'User not authenticated. Please sign in to delete tasks.',
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }
    try {
      await _offlineService.saveTask(
        TaskModel(
          id: taskId,
          title: '',
          description: '',
          status: '',
          updatedAt: DateTime.now(),
          updatedBy: _firebaseService.currentUserId!,
        ),
        action: 'delete',
      );
      await _ref.read(tasksControllerProvider.notifier).deleteTask(taskId);
      Fluttertoast.showToast(
        msg: 'Task deleted',
        toastLength: Toast.LENGTH_SHORT,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to delete task: $e',
        toastLength: Toast.LENGTH_LONG,
      );
      print('Error deleting task $taskId: $e');
    }
  }

  Future<void> uploadAttachments(String taskId, List<File> files) async {
    if (_firebaseService.currentUserId == null) {
      Fluttertoast.showToast(
        msg: 'User not authenticated. Please sign in to upload files.',
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }
    try {
      for (var file in files) {
        if (!file.existsSync()) {
          Fluttertoast.showToast(
            msg: 'File not found: ${file.path}',
            toastLength: Toast.LENGTH_LONG,
          );
          print('File not found: ${file.path}');
          continue;
        }
        final fileSizeMB = (await file.length()) / (1024 * 1024);
        if (fileSizeMB > Constants.maxFileSizeMB) {
          Fluttertoast.showToast(
            msg:
                'File too large: ${file.path.split('/').last} (${fileSizeMB.toStringAsFixed(1)}MB)',
            toastLength: Toast.LENGTH_LONG,
          );
          print('File too large: ${file.path}');
          continue;
        }
        final storagePath =
            '${Constants.attachmentsPath}/$taskId/${file.path.split('/').last}';
        await _offlineService.queueFileUpload(taskId, file, storagePath);
        print('Queued upload for task $taskId: ${file.path}');
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to queue attachments: $e',
        toastLength: Toast.LENGTH_LONG,
      );
      print('Error queuing attachments for task $taskId: $e');
    }
  }

  Future<void> syncTasks() async {
    if (_firebaseService.currentUserId == null) {
      print('Skipping task sync: User not authenticated');
      return;
    }
    final tasks = await _offlineService.getLocalTasks();
    for (var task
        in tasks.where((t) => !t.isSynced && !_syncedTaskIds.contains(t.id))) {
      try {
        _syncedTaskIds.add(task.id); // Mark task as being processed
        if (task.pendingAction == 'add') {
          await _firebaseService.addTask(task);
          await _offlineService.markTaskAsSynced(task.id);
          print('Synced task ${task.id} to Firebase');
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
              print('Merged and synced task ${task.id}');
            } else {
              await docRef.set(task.toJson());
              print('Synced updated task ${task.id}');
            }
          } else {
            await docRef.set(task.toJson());
            print('Synced new task ${task.id}');
          }
          await _offlineService.markTaskAsSynced(task.id);
        } else if (task.pendingAction == 'delete') {
          await _firebaseService.deleteTask(task.id);
          await _offlineService.deleteLocalTask(task.id);
          print('Deleted task ${task.id} from Firebase');
        }
      } catch (e) {
        Fluttertoast.showToast(
          msg: 'Sync failed for task ${task.title}: $e',
          toastLength: Toast.LENGTH_LONG,
        );
        print('Error syncing task ${task.id}: $e');
      } finally {
        // Remove task from session cache after processing
        _syncedTaskIds.remove(task.id);
      }
    }
  }

  Future<void> syncUploads() async {
    if (_firebaseService.currentUserId == null) {
      print('Skipping upload sync: User not authenticated');
      return;
    }
    final uploads = await _offlineService.getPendingUploads();
    for (var upload in uploads) {
      try {
        final file = File(upload['filePath']!);
        if (!file.existsSync()) {
          Fluttertoast.showToast(
            msg: 'File not found: ${upload['filePath']}',
            toastLength: Toast.LENGTH_LONG,
          );
          await _offlineService.clearPendingUpload(
              upload['taskId']!, upload['filePath']!);
          print('Cleared missing file: ${upload['filePath']}');
          continue;
        }
        final url = await _storageService.uploadFile(upload['taskId']!, file);
        final task = (await _offlineService.getLocalTasks())
            .firstWhere((t) => t.id == upload['taskId'], orElse: () {
          Fluttertoast.showToast(
            msg: 'Task ${upload['taskId']} not found for upload',
            toastLength: Toast.LENGTH_LONG,
          );
          throw Exception('Task not found');
        });
        final updatedTask = task.copyWith(
          attachments: [...task.attachments, url],
          updatedAt: DateTime.now(),
          updatedBy: _firebaseService.currentUserId!,
        );
        await updateTask(updatedTask);
        await _offlineService.clearPendingUpload(
            upload['taskId']!, upload['filePath']!);
        Fluttertoast.showToast(
          msg: 'File uploaded for task ${task.title}',
          toastLength: Toast.LENGTH_SHORT,
        );
        print('Uploaded file for task ${task.id}: $url');
      } catch (e) {
        Fluttertoast.showToast(
          msg: 'Upload failed for task ${upload['taskId']}: $e',
          toastLength: Toast.LENGTH_LONG,
        );
        print('Error uploading file for task ${upload['taskId']}: $e');
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
    );
  }
}
