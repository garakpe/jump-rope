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
  final String group;
  final int currentLevel;
  final Map<String, TaskProgress> individualProgress;
  final Map<String, TaskProgress> groupProgress;
  final bool attendance;
  final String studentId;
  final String classNum; // 추가: 반 정보 (두자리 문자열)
  final String studentNum; // 추가: 번호 정보 (두자리 문자열)
  final String grade; // 추가: 학년 정보

  StudentProgress({
    required this.id,
    required this.name,
    required this.number,
    required this.group,
    this.currentLevel = 1,
    this.individualProgress = const {},
    this.groupProgress = const {},
    this.attendance = true,
    this.studentId = '',
    this.classNum = '', // 기본값 추가
    this.studentNum = '', // 기본값 추가
    this.grade = '', // 기본값 추가
  });

  StudentProgress copyWith({
    String? id,
    String? name,
    int? number,
    String? group,
    int? currentLevel,
    Map<String, TaskProgress>? individualProgress,
    Map<String, TaskProgress>? groupProgress,
    bool? attendance,
    String? studentId,
    String? classNum, // copyWith에 추가
    String? studentNum, // copyWith에 추가
    String? grade, // copyWith에 추가
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
      studentId: studentId ?? this.studentId,
      classNum: classNum ?? this.classNum, // 필드 추가
      studentNum: studentNum ?? this.studentNum, // 필드 추가
      grade: grade ?? this.grade, // 필드 추가
    );
  }
}
