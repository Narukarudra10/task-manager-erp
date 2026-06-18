class TaskAttachment {
  final int id;
  final int taskId;
  final String fileName;
  final String fileUrl;
  final String fileType;
  final int fileSize;
  final DateTime createdAt;

  TaskAttachment({
    required this.id,
    required this.taskId,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
    required this.createdAt,
  });

  factory TaskAttachment.fromJson(Map<String, dynamic> json) {
    return TaskAttachment(
      id: json['id'] as int,
      taskId: json['taskId'] as int,
      fileName: json['fileName'] as String,
      fileUrl: json['fileUrl'] as String,
      fileType: json['fileType'] as String,
      fileSize: json['fileSize'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'fileSize': fileSize,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class Task {
  final int id;
  final String userId;
  final String? assignedTo;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? creatorName;
  final String? creatorEmail;
  final String? creatorImage;
  final String? assigneeName;
  final String? assigneeEmail;
  final String? assigneeImage;
  final List<TaskAttachment> attachments;

  Task({
    required this.id,
    required this.userId,
    this.assignedTo,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.creatorName,
    this.creatorEmail,
    this.creatorImage,
    this.assigneeName,
    this.assigneeEmail,
    this.assigneeImage,
    required this.attachments,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    var list = json['attachments'] as List? ?? [];
    List<TaskAttachment> attachmentList =
        list.map((i) => TaskAttachment.fromJson(i as Map<String, dynamic>)).toList();

    return Task(
      id: json['id'] as int,
      userId: json['userId'] as String,
      assignedTo: json['assignedTo'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      priority: json['priority'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
      creatorName: json['creatorName'] as String?,
      creatorEmail: json['creatorEmail'] as String?,
      creatorImage: json['creatorImage'] as String?,
      assigneeName: json['assigneeName'] as String?,
      assigneeEmail: json['assigneeEmail'] as String?,
      assigneeImage: json['assigneeImage'] as String?,
      attachments: attachmentList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'assignedTo': assignedTo,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'creatorName': creatorName,
      'creatorEmail': creatorEmail,
      'creatorImage': creatorImage,
      'assigneeName': assigneeName,
      'assigneeEmail': assigneeEmail,
      'assigneeImage': assigneeImage,
      'attachments': attachments.map((a) => a.toJson()).toList(),
    };
  }
}
