// lib/models/ui_models.dart
class TaskProgress {
  final String taskName;
  final String? completedDate;
  final bool isCompleted;

  TaskProgress({
    required this.taskName,
    this.completedDate,
    this.isCompleted = false,
  });
}

class StudentProgress {
  final String id;
  final String name;
  final int number;
  final int group;
  final int currentLevel;
  final Map<String, TaskProgress> individualProgress;
  final Map<String, TaskProgress> groupProgress;
  final bool attendance;

  StudentProgress({
    required this.id,
    required this.name,
    required this.number,
    required this.group,
    this.currentLevel = 1,
    this.individualProgress = const {},
    this.groupProgress = const {},
    this.attendance = true,
  });

  StudentProgress copyWith({
    String? id,
    String? name,
    int? number,
    int? group,
    int? currentLevel,
    Map<String, TaskProgress>? individualProgress,
    Map<String, TaskProgress>? groupProgress,
    bool? attendance,
  }) {
    return StudentProgress(
      id: id ?? this.id,
      name: name ?? this.name,
      number: number ?? this.number,
      group: group ?? this.group,
      currentLevel: currentLevel ?? this.currentLevel,
      individualProgress: individualProgress ?? this.individualProgress,
      groupProgress: groupProgress ?? this.groupProgress,
      attendance: attendance ?? this.attendance,
    );
  }
}
