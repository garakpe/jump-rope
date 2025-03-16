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

// 변경 후
class StudentProgress {
  final String id;
  final String name;
  final int number;
  final String group;
  final String classNum; // 추가
  final int currentLevel;
  final Map<String, TaskProgress> individualProgress;
  final Map<String, TaskProgress> groupProgress;
  final bool attendance;
  final String studentId; // 추가된 필드

  StudentProgress({
    required this.id,
    required this.name,
    required this.number,
    required this.group,
    this.classNum = '', // 추가
    this.currentLevel = 1,
    this.individualProgress = const {},
    this.groupProgress = const {},
    this.attendance = true,
    this.studentId = '', // 기본값 추가
  });

  StudentProgress copyWith({
    String? id,
    String? name,
    int? number,
    String? group,
    int? currentLevel,
    String? classNum, // 추가
    Map<String, TaskProgress>? individualProgress,
    Map<String, TaskProgress>? groupProgress,
    bool? attendance,
    String? studentId, // copyWith에도 추가
  }) {
    return StudentProgress(
      id: id ?? this.id,
      name: name ?? this.name,
      number: number ?? this.number,
      group: group ?? this.group,
      classNum: classNum ?? this.classNum, // 추가
      currentLevel: currentLevel ?? this.currentLevel,
      individualProgress: individualProgress ?? this.individualProgress,
      groupProgress: groupProgress ?? this.groupProgress,
      attendance: attendance ?? this.attendance,
      studentId: studentId ?? this.studentId, // 필드 추가
    );
  }
}
