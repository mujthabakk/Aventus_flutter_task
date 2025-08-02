import 'package:sqflite/sqflite.dart';
import '../config/constants.dart';
import '../models/task_model.dart';
import 'dart:io';

class OfflineService {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, Constants.dbName),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks(
            id TEXT PRIMARY KEY,
            title TEXT,
            description TEXT,
            status TEXT,
            assignedTo TEXT,
            updatedAt TEXT,
            updatedBy TEXT,
            attachments TEXT,
            isSynced INTEGER,
            pendingAction TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE pending_uploads(
            taskId TEXT,
            filePath TEXT,
            storagePath TEXT
          )
        ''');
      },
    );
  }

  Future<void> saveTask(TaskModel task, {String? action}) async {
    final db = await database;
    await db.insert(
      'tasks',
      {
        ...task.toJson(),
        'isSynced': 0,
        'pendingAction': action ?? 'add',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TaskModel>> getLocalTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('tasks');
    return maps.map((map) => TaskModel.fromJson(map)).toList();
  }

  Future<void> queueFileUpload(
      String taskId, File file, String storagePath) async {
    final db = await database;
    await db.insert('pending_uploads', {
      'taskId': taskId,
      'filePath': file.path,
      'storagePath': storagePath,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingUploads() async {
    final db = await database;
    return await db.query('pending_uploads');
  }

  Future<void> clearPendingUpload(String taskId, String filePath) async {
    final db = await database;
    await db.delete(
      'pending_uploads',
      where: 'taskId = ? AND filePath = ?',
      whereArgs: [taskId, filePath],
    );
  }

  Future<void> markTaskAsSynced(String taskId) async {
    final db = await database;
    await db.update(
      'tasks',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  Future<void> deleteLocalTask(String taskId) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [taskId]);
  }
}
