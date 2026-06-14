enum CleaningFrequency { daily, weekly, monthly }

enum CleaningTime { morning, daytime, evening, anytime }

enum CleaningEventStatus { completed, skipped }

class CleaningMember {
  const CleaningMember({
    required this.id,
    required this.name,
    required this.colorValue,
    this.isActive = true,
  });

  factory CleaningMember.fromJson(Map<String, dynamic> json) {
    return CleaningMember(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      colorValue: json['colorValue'] as int? ?? 0xFF4F8DF7,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final int colorValue;
  final bool isActive;

  CleaningMember copyWith({String? name, bool? isActive}) {
    return CleaningMember(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'isActive': isActive,
    };
  }
}

class CleaningTask {
  const CleaningTask({
    required this.id,
    required this.label,
    required this.area,
    required this.minutes,
    required this.frequency,
    required this.time,
    this.weekdays = const [],
    this.monthDay,
    this.essential = false,
    this.custom = false,
    this.isActive = true,
    this.assigneeIds = const [],
    this.rotateAssignees = false,
  });

  factory CleaningTask.fromJson(Map<String, dynamic> json) {
    return CleaningTask(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      area: json['area'] as String? ?? 'Whole house',
      minutes: json['minutes'] as int? ?? 10,
      frequency: CleaningFrequency.values.byName(
        json['frequency'] as String? ?? 'daily',
      ),
      time: CleaningTime.values.byName(json['time'] as String? ?? 'anytime'),
      weekdays: (json['weekdays'] as List<dynamic>? ?? const [])
          .whereType<int>()
          .toList(),
      monthDay: json['monthDay'] as int?,
      essential: json['essential'] as bool? ?? false,
      custom: json['custom'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      assigneeIds: (json['assigneeIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      rotateAssignees: json['rotateAssignees'] as bool? ?? false,
    );
  }

  final String id;
  final String label;
  final String area;
  final int minutes;
  final CleaningFrequency frequency;
  final CleaningTime time;
  final List<int> weekdays;
  final int? monthDay;
  final bool essential;
  final bool custom;
  final bool isActive;
  final List<String> assigneeIds;
  final bool rotateAssignees;

  bool isDue(DateTime date) {
    if (!isActive) return false;
    return switch (frequency) {
      CleaningFrequency.daily => true,
      CleaningFrequency.weekly => weekdays.contains(date.weekday),
      CleaningFrequency.monthly => date.day == (monthDay ?? 1),
    };
  }

  CleaningTask copyWith({
    bool? isActive,
    List<String>? assigneeIds,
    bool? rotateAssignees,
  }) {
    return CleaningTask(
      id: id,
      label: label,
      area: area,
      minutes: minutes,
      frequency: frequency,
      time: time,
      weekdays: weekdays,
      monthDay: monthDay,
      essential: essential,
      custom: custom,
      isActive: isActive ?? this.isActive,
      assigneeIds: assigneeIds ?? this.assigneeIds,
      rotateAssignees: rotateAssignees ?? this.rotateAssignees,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'area': area,
      'minutes': minutes,
      'frequency': frequency.name,
      'time': time.name,
      'weekdays': weekdays,
      'monthDay': monthDay,
      'essential': essential,
      'custom': custom,
      'isActive': isActive,
      'assigneeIds': assigneeIds,
      'rotateAssignees': rotateAssignees,
    };
  }
}

class CleaningEvent {
  const CleaningEvent({
    required this.taskId,
    required this.scheduledDate,
    required this.recordedAt,
    required this.status,
    this.completedByMemberId,
  });

  factory CleaningEvent.fromJson(Map<String, dynamic> json) {
    return CleaningEvent(
      taskId: json['taskId'] as String? ?? '',
      scheduledDate: DateTime.parse(json['scheduledDate'] as String),
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      status: CleaningEventStatus.values.byName(
        json['status'] as String? ?? 'completed',
      ),
      completedByMemberId: json['completedByMemberId'] as String?,
    );
  }

  final String taskId;
  final DateTime scheduledDate;
  final DateTime recordedAt;
  final CleaningEventStatus status;
  final String? completedByMemberId;

  String get key => '$taskId:${cleaningDateKey(scheduledDate)}';

  bool get completedLate =>
      cleaningDateOnly(recordedAt).isAfter(cleaningDateOnly(scheduledDate));

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'scheduledDate': scheduledDate.toIso8601String(),
      'recordedAt': recordedAt.toIso8601String(),
      'status': status.name,
      'completedByMemberId': completedByMemberId,
    };
  }
}

class CleaningData {
  const CleaningData({
    required this.tasks,
    required this.events,
    this.members = const [],
    this.trackingStartedAt,
  });

  final List<CleaningTask> tasks;
  final List<CleaningEvent> events;
  final List<CleaningMember> members;
  final DateTime? trackingStartedAt;

  CleaningData copyWith({
    List<CleaningTask>? tasks,
    List<CleaningEvent>? events,
    List<CleaningMember>? members,
  }) {
    return CleaningData(
      tasks: tasks ?? this.tasks,
      events: events ?? this.events,
      members: members ?? this.members,
      trackingStartedAt: trackingStartedAt,
    );
  }
}

CleaningMember? assignedCleaningMember(
  CleaningTask task,
  DateTime date,
  List<CleaningMember> members,
) {
  final activeMembers = {
    for (final member in members)
      if (member.isActive) member.id: member,
  };
  final assignees = task.assigneeIds
      .where(activeMembers.containsKey)
      .map((id) => activeMembers[id]!)
      .toList();
  if (assignees.isEmpty) return null;
  if (!task.rotateAssignees || assignees.length == 1) return assignees.first;

  final normalizedDate = cleaningDateOnly(date);
  final index = switch (task.frequency) {
    CleaningFrequency.daily => normalizedDate.difference(DateTime(2020)).inDays,
    CleaningFrequency.weekly =>
      normalizedDate.difference(DateTime(2020)).inDays ~/ 7,
    CleaningFrequency.monthly =>
      (normalizedDate.year - 2020) * 12 + normalizedDate.month,
  };
  return assignees[index.abs() % assignees.length];
}

DateTime cleaningDateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

String cleaningDateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
