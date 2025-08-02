import 'package:kanban_board/core/models/task_model.dart';

extension TaskModelCopyWith on TaskModel {
  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    String? status,
    String? assignedTo,
    DateTime? updatedAt,
    String? updatedBy,
    List<String>? attachments,
    bool? isSynced,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      attachments: attachments ?? this.attachments,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
