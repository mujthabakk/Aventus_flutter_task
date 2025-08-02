class TaskModel {
  final String id;
  final String title;
  final String description;
  final String status;
  final String assignedTo;
  final DateTime updatedAt;
  final String updatedBy;
  final List<String> attachments;
  final bool isSynced;
  final String? pendingAction;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.assignedTo,
    required this.updatedAt,
    required this.updatedBy,
    this.attachments = const [],
    this.isSynced = false,
    this.pendingAction,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      status: json['status'],
      assignedTo: json['assignedTo'],
      updatedAt: DateTime.parse(json['updatedAt']),
      updatedBy: json['updatedBy'],
      attachments: List<String>.from(json['attachments'] ?? []),
      isSynced: json['isSynced'] == 1,
      pendingAction: json['pendingAction'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'assignedTo': assignedTo,
      'updatedAt': updatedAt.toIso8601String(),
      'updatedBy': updatedBy,
      'attachments': attachments,
      'isSynced': isSynced ? 1 : 0,
      'pendingAction': pendingAction,
    };
  }
}
