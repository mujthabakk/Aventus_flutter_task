class TaskModel {
  final String id;
  final String title;
  final String description;
  final String status;
  final DateTime updatedAt;
  final String updatedBy;
  final List<String> attachments;
  final bool isSynced;
  final String pendingAction;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.updatedAt,
    required this.updatedBy,
    this.attachments = const [],
    this.isSynced = false,
    this.pendingAction = '',
  });

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    String? status,
    DateTime? updatedAt,
    String? updatedBy,
    List<String>? attachments,
    bool? isSynced,
    String? pendingAction,
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
      pendingAction: pendingAction ?? this.pendingAction,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'updatedAt': updatedAt.toIso8601String(),
      'updatedBy': updatedBy,
      'attachments': attachments,
      'isSynced': isSynced,
      'pendingAction': pendingAction,
    };
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? '',
      updatedAt:
          DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      updatedBy: json['updatedBy'] ?? '',
      attachments: List<String>.from(json['attachments'] ?? []),
      isSynced: json['isSynced'] ?? false,
      pendingAction: json['pendingAction'] ?? '',
    );
  }
}
