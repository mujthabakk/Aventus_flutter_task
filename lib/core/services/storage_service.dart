import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:fluttertoast/fluttertoast.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadFile(String taskId, File file) async {
    try {
      final ref = _storage
          .ref()
          .child('attachments/$taskId/${file.path.split('/').last}');
      final uploadTask = await ref.putFile(file);
      final url = await uploadTask.ref.getDownloadURL();
      print('Uploaded file for task $taskId: $url');
      return url;
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to upload file: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
      print('Error uploading file for task $taskId: $e');
      rethrow;
    }
  }
}
