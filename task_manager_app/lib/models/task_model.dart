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

class TaskAssignee {
  final String userId;
  final String? name;
  final String? email;
  final String? image;

  TaskAssignee({
    required this.userId,
    this.name,
    this.email,
    this.image,
  });

  factory TaskAssignee.fromJson(Map<String, dynamic> json) {
    return TaskAssignee(
      userId: json['userId'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      image: json['image'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'image': image,
    };
  }

  String get initials {
    if (name == null || name!.isEmpty) return '?';
    final parts = name!.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class Task {
  final int id;
  final String userId;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? creatorName;
  final String? creatorEmail;
  final String? creatorImage;
  final List<TaskAssignee> assignees;
  final List<TaskAttachment> attachments;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.creatorName,
    this.creatorEmail,
    this.creatorImage,
    required this.assignees,
    required this.attachments,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    var attachmentList = <TaskAttachment>[];
    final rawAttachments = json['attachments'] as List?;
    if (rawAttachments != null) {
      attachmentList = rawAttachments
          .map((i) => TaskAttachment.fromJson(i as Map<String, dynamic>))
          .toList();
    }

    var assigneeList = <TaskAssignee>[];
    final rawAssignees = json['assignees'] as List?;
    if (rawAssignees != null) {
      assigneeList = rawAssignees
          .map((i) => TaskAssignee.fromJson(i as Map<String, dynamic>))
          .toList();
    } else {
      // Backward compatibility: old single assignedTo field
      final assignedTo = json['assignedTo'] as String?;
      if (assignedTo != null) {
        assigneeList = [
          TaskAssignee(
            userId: assignedTo,
            name: json['assigneeName'] as String?,
            email: json['assigneeEmail'] as String?,
            image: json['assigneeImage'] as String?,
          ),
        ];
      }
    }

    return Task(
      id: json['id'] as int,
      userId: json['userId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      priority: json['priority'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
      creatorName: json['creatorName'] as String?,
      creatorEmail: json['creatorEmail'] as String?,
      creatorImage: json['creatorImage'] as String?,
      assignees: assigneeList,
      attachments: attachmentList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'creatorName': creatorName,
      'creatorEmail': creatorEmail,
      'creatorImage': creatorImage,
      'assignees': assignees.map((a) => a.toJson()).toList(),
      'attachments': attachments.map((a) => a.toJson()).toList(),
    };
  }
}
