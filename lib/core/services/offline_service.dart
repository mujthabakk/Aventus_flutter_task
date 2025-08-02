import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task_model.dart';
import 'dart:io';
import 'package:fluttertoast/fluttertoast.dart';

class OfflineService {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'kanban.db');
    print('Initializing database at: $path');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        print('Creating tables for version $version');
        await db.execute('''
          CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            title TEXT,
            description TEXT,
            status TEXT,
            updatedAt TEXT,
            updatedBy TEXT,
            attachments TEXT,
            isSynced INTEGER,
            pendingAction TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE pending_uploads (
            taskId TEXT,
            filePath TEXT,
            storagePath TEXT,
            PRIMARY KEY (taskId, filePath)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print('Upgrading database from version $oldVersion to $newVersion');
        if (oldVersion < 2) {
          try {
            // Create a new table without assignedTo
            await db.execute('''
              CREATE TABLE tasks_new (
                id TEXT PRIMARY KEY,
                title TEXT,
                description TEXT,
                status TEXT,
                updatedAt TEXT,
                updatedBy TEXT,
                attachments TEXT,
                isSynced INTEGER,
                pendingAction TEXT
              )
            ''');
            // Copy data from old tasks table to new one, excluding assignedTo
            await db.execute('''
              INSERT INTO tasks_new (id, title, description, status, updatedAt, updatedBy, attachments, isSynced, pendingAction)
              SELECT id, title, description, status, updatedAt, updatedBy, attachments, isSynced, pendingAction
              FROM tasks
            ''');
            // Drop old table and rename new one
            await db.execute('DROP TABLE tasks');
            await db.execute('ALTER TABLE tasks_new RENAME TO tasks');
            print('Successfully upgraded tasks table by removing assignedTo');
          } catch (e) {
            Fluttertoast.showToast(
              msg: 'Failed to upgrade database: $e',
              toastLength: Toast.LENGTH_LONG,
            );
            print('Error upgrading database: $e');
          }
        }
      },
    );
  }

  Future<void> saveTask(TaskModel task, {required String action}) async {
    final db = await database;
    try {
      await db.insert(
        'tasks',
        {
          ...task.toJson(),
          'isSynced': task.isSynced ? 1 : 0,
          'pendingAction': action,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('Saved task ${task.id} locally with action: $action');
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to save task locally: $e',
        toastLength: Toast.LENGTH_LONG,
      );
      print('Error saving task ${task.id}: $e');
    }
  }

  Future<List<TaskModel>> getLocalTasks() async {
    final db = await database;
    try {
      final maps = await db.query('tasks');
      final tasks = maps
          .map((map) => TaskModel.fromJson({
                ...map,
                'isSynced': map['isSynced'] == 1,
                'attachments': map['attachments']
                        ?.toString()
                        .split(',')
                        .where((s) => s.isNotEmpty)
                        .toList() ??
                    [],
              }))
          .toList();
      print('Loaded ${tasks.length} tasks from local database');
      return tasks;
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to load local tasks: $e',
        toastLength: Toast.LENGTH_LONG,
      );
      print('Error loading local tasks: $e');
      return [];
    }
  }

  Future<void> markTaskAsSynced(String taskId) async {
    final db = await database;
    try {
      await db.update(
        'tasks',
        {'isSynced': 1, 'pendingAction': ''},
        where: 'id = ?',
        whereArgs: [taskId],
      );
      print('Marked task $taskId as synced');
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to mark task as synced: $e',
        toastLength: Toast.LENGTH_LONG,
      );
      print('Error marking task $taskId as synced: $e');
    }
  }

  Future<void> deleteLocalTask(String taskId) async {
    final db = await database;
    try {
      await db.delete('tasks', where: 'id = ?', whereArgs: [taskId]);
      print('Deleted task $taskId locally');
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to delete local task: $e',
        toastLength: Toast.LENGTH_LONG,
      );
      print('Error deleting task $taskId: $e');
    }
  }

  Future<void> queueFileUpload(
      String taskId, File file, String storagePath) async {
    final db = await database;
    try {
      await db.insert(
        'pending_uploads',
        {
          'taskId': taskId,
          'filePath': file.path,
          'storagePath': storagePath,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('Queued upload for task $taskId: ${file.path}');
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to queue file upload: $e',
        toastLength: Toast.LENGTH_LONG,
      );
      print('Error queuing upload for task $taskId: $e');
    }
  }

  Future<List<Map<String, String>>> getPendingUploads() async {
    final db = await database;
    try {
      final uploads =
          (await db.query('pending_uploads')).cast<Map<String, String>>();
      print('Loaded ${uploads.length} pending uploads');
      return uploads;
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to load pending uploads: $e',
        toastLength: Toast.LENGTH_LONG,
      );
      print('Error loading pending uploads: $e');
      return [];
    }
  }

  Future<void> clearPendingUpload(String taskId, String filePath) async {
    final db = await database;
    try {
      await db.delete(
        'pending_uploads',
        where: 'taskId = ? AND filePath = ?',
        whereArgs: [taskId, filePath],
      );
      print('Cleared pending upload for task $taskId: $filePath');
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to clear pending upload: $e',
        toastLength: Toast.LENGTH_LONG,
      );
      print('Error clearing pending upload for task $taskId: $e');
    }
  }
}
