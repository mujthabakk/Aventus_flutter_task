import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kanban_board/features/kanban/providers/kanban_provider.dart';
import 'dart:io';
import '../../../core/models/task_model.dart';

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
  late String _assignedTo;
  List<File> _attachments = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.task?.description ?? '');
    _status = widget.task?.status ?? 'To Do';
    _assignedTo = widget.task?.assignedTo ?? '';
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
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'pdf'],
    );
    if (result != null) {
      setState(() {
        _attachments.addAll(result.paths.map((path) => File(path!)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = ref.read(firebaseServiceProvider);

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
              TextFormField(
                initialValue: _assignedTo,
                decoration:
                    const InputDecoration(labelText: 'Assigned To (User ID)'),
                onChanged: (value) => _assignedTo = value,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _pickFiles,
                child: const Text('Attach Files'),
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
            onPressed: () async {
              await ref
                  .read(tasksControllerProvider.notifier)
                  .deleteTask(widget.task!.id);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final task = TaskModel(
                id: widget.task?.id ?? '',
                title: _titleController.text,
                description: _descriptionController.text,
                status: _status,
                assignedTo: _assignedTo,
                updatedAt: DateTime.now(),
                updatedBy: firebaseService.currentUserId ?? '',
                attachments: widget.task?.attachments ?? [],
              );
              if (widget.task == null) {
                await ref.read(tasksControllerProvider.notifier).addTask(task);
              } else {
                await ref
                    .read(tasksControllerProvider.notifier)
                    .updateTask(task);
              }
              if (_attachments.isNotEmpty) {
                await ref
                    .read(tasksControllerProvider.notifier)
                    .uploadAttachments(task.id, _attachments);
              }
              if (mounted) Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
