import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../config/constants.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadFile(String taskId, File file) async {
    final storagePath =
        '${Constants.attachmentsPath}/$taskId/${file.path.split('/').last}';
    final ref = _storage.ref().child(storagePath);
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      // Handle error silently
    }
  }
}
