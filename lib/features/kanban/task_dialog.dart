import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kanban_board/features/kanban/providers/kanban_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../../../core/models/task_model.dart';
import 'package:fluttertoast/fluttertoast.dart';

class TaskDialog extends ConsumerStatefulWidget {
  final TaskModel? task;

  const TaskDialog({this.task, super.key});

  @override
  ConsumerState<TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends ConsumerState<TaskDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late String _status;
  List<File> _attachments = [];
  bool _isSaving = false;
  bool _isPickingFiles = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.task?.description ?? '');
    _status = widget.task?.status ?? 'To Do';
    _attachments =
        widget.task?.attachments.map((url) => File(url)).toList() ?? [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    setState(() => _isPickingFiles = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'pdf'],
      );
      if (result != null) {
        final validFiles = result.paths
            .map((path) => File(path!))
            .where((file) => file.existsSync())
            .toList();
        if (validFiles.isEmpty) {
          Fluttertoast.showToast(
            msg: 'No valid files selected',
            toastLength: Toast.LENGTH_SHORT,
          );
        } else {
          setState(() {
            _attachments.addAll(validFiles);
          });
          Fluttertoast.showToast(
            msg: '${validFiles.length} file(s) added',
            toastLength: Toast.LENGTH_SHORT,
          );
        }
      }
    } finally {
      setState(() => _isPickingFiles = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = ref.read(firebaseServiceProvider);

    if (firebaseService.currentUserId == null) {
      return AuthDialog(
        onAuthenticated: () {
          Navigator.pop(context);
          showDialog(
            context: context,
            builder: (_) => TaskDialog(task: widget.task),
          );
        },
      );
    }

    return AlertDialog(
      title: Text(widget.task == null ? 'New Task' : 'Edit Task'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: ['To Do', 'In Progress', 'Done']
                    .map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _status = value!),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isPickingFiles || _isSaving ? null : _pickFiles,
                child: _isPickingFiles
                    ? const CircularProgressIndicator()
                    : const Text('Attach Files'),
              ),
              if (_attachments.isNotEmpty)
                Column(
                  children: _attachments
                      .map((file) => ListTile(
                            title: Text(file.path.split('/').last),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => setState(() {
                                _attachments.remove(file);
                              }),
                            ),
                          ))
                      .toList(),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.task != null)
          TextButton(
            onPressed: _isSaving
                ? null
                : () async {
                    setState(() => _isSaving = true);
                    try {
                      await ref
                          .read(tasksControllerProvider.notifier)
                          .deleteTask(widget.task!.id);
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      Fluttertoast.showToast(
                        msg: 'Failed to delete task: $e',
                        toastLength: Toast.LENGTH_LONG,
                      );
                    } finally {
                      setState(() => _isSaving = false);
                    }
                  },
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isSaving
              ? null
              : () async {
                  if (_formKey.currentState!.validate()) {
                    setState(() => _isSaving = true);
                    try {
                      final taskId = widget.task?.id ?? const Uuid().v4();
                      final task = TaskModel(
                        id: taskId,
                        title: _titleController.text,
                        description: _descriptionController.text,
                        status: _status,
                        updatedAt: DateTime.now(),
                        updatedBy: firebaseService.currentUserId!,
                        attachments: widget.task?.attachments ?? [],
                      );
                      if (widget.task == null) {
                        await ref
                            .read(tasksControllerProvider.notifier)
                            .addTask(task);
                      } else {
                        await ref
                            .read(tasksControllerProvider.notifier)
                            .updateTask(task);
                      }
                      if (_attachments.isNotEmpty) {
                        await ref
                            .read(tasksControllerProvider.notifier)
                            .uploadAttachments(taskId, _attachments);
                        Fluttertoast.showToast(
                          msg: 'Attachments queued for upload',
                          toastLength: Toast.LENGTH_SHORT,
                        );
                      }
                      // Close dialog immediately after local save
                      if (mounted) Navigator.pop(context);
                      // Trigger sync in background
                      ref.read(kanbanControllerProvider).syncTasks();
                      ref.read(kanbanControllerProvider).syncUploads();
                    } catch (e) {
                      Fluttertoast.showToast(
                        msg: 'Failed to save task: $e',
                        toastLength: Toast.LENGTH_LONG,
                      );
                    } finally {
                      setState(() => _isSaving = false);
                    }
                  }
                },
          child: _isSaving
              ? const CircularProgressIndicator()
              : const Text('Save'),
        ),
      ],
    );
  }
}

class AuthDialog extends ConsumerStatefulWidget {
  final VoidCallback onAuthenticated;

  const AuthDialog({required this.onAuthenticated, super.key});

  @override
  ConsumerState<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends ConsumerState<AuthDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false; // Fixed: Changed to non-final to allow state changes
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    setState(() => _isLoading = true);
    final firebaseService = ref.read(firebaseServiceProvider);
    try {
      if (_isSignUp) {
        await firebaseService.signUp(
            _emailController.text, _passwordController.text);
      } else {
        await firebaseService.signIn(
            _emailController.text, _passwordController.text);
      }
      if (mounted) {
        widget.onAuthenticated();
        Navigator.pop(context);
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: _isSignUp ? 'Sign-up failed: $e' : 'Sign-in failed: $e',
        toastLength: Toast.LENGTH_LONG,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isSignUp ? 'Sign Up' : 'Sign In'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _isSignUp =
                  !_isSignUp), // Fixed: Use setState to toggle _isSignUp
              child: Text(
                _isSignUp
                    ? 'Already have an account? Sign In'
                    : 'Need an account? Sign Up',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isLoading
              ? null
              : () async {
                  if (_emailController.text.isNotEmpty &&
                      _passwordController.text.isNotEmpty) {
                    await _authenticate();
                  } else {
                    Fluttertoast.showToast(
                      msg: 'Please enter email and password',
                      toastLength: Toast.LENGTH_SHORT,
                    );
                  }
                },
          child: _isLoading
              ? const CircularProgressIndicator()
              : Text(_isSignUp ? 'Sign Up' : 'Sign In'),
        ),
      ],
    );
  }
}
