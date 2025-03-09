// lib/models/ui_models.dart

/// 과제 진행 상태 모델
///
/// 특정 과제의 완료 여부와 완료 날짜를 관리합니다.
class TaskProgress {
  /// 과제 이름
  final String taskName;

  /// 완료 날짜 (완료되지 않은 경우 null)
  final String? completedDate;

  /// 과제 완료 여부
  final bool isCompleted;

  /// 생성자
  TaskProgress({
    required this.taskName,
    this.completedDate,
    this.isCompleted = false,
  });

  /// 현재 객체를 기반으로 새 인스턴스 생성 (일부 속성만 변경)
  TaskProgress copyWith({
    String? taskName,
    String? completedDate,
    bool? isCompleted,
  }) {
    return TaskProgress(
      taskName: taskName ?? this.taskName,
      completedDate: completedDate ?? this.completedDate,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  String toString() {
    return 'TaskProgress(taskName: $taskName, isCompleted: $isCompleted, completedDate: $completedDate)';
  }
}

/// 학생 진행 상황 모델
///
/// 특정 학생의 모든 과제 진행 상황을 관리합니다.
class StudentProgress {
  /// 학생 ID
  final String id;

  /// 학생 이름
  final String name;

  /// 학생 번호
  final int number;

  /// 모둠 번호
  final int group;

  /// 현재 레벨
  final int currentLevel;

  /// 개인 줄넘기 과제 진행 상황
  /// 키: 과제 이름, 값: 진행 상황
  final Map<String, TaskProgress> individualProgress;

  /// 단체 줄넘기 과제 진행 상황
  /// 키: 과제 이름, 값: 진행 상황
  final Map<String, TaskProgress> groupProgress;

  /// 출석 여부
  final bool attendance;

  /// 생성자
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

  /// 현재 객체를 기반으로 새 인스턴스 생성 (일부 속성만 변경)
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

  /// 개인 과제 성공 개수
  int get individualSuccessCount =>
      individualProgress.values.where((p) => p.isCompleted).length;

  /// 단체 과제 성공 개수
  int get groupSuccessCount =>
      groupProgress.values.where((p) => p.isCompleted).length;

  /// 전체 성공 과제 개수
  int get totalSuccessCount => individualSuccessCount + groupSuccessCount;

  /// 특정 과제 진행 상황 가져오기
  TaskProgress? getTaskProgress(String taskName, bool isIndividual) {
    final progress = isIndividual ? individualProgress : groupProgress;
    return progress[taskName];
  }

  @override
  String toString() {
    return 'StudentProgress(id: $id, name: $name, number: $number, group: $group, individualSuccess: $individualSuccessCount, groupSuccess: $groupSuccessCount)';
  }
}

/// 학급 진행 상황 요약 모델
class ClassProgressSummary {
  /// 학급 ID (반 번호)
  final String classId;

  /// 학생 수
  final int studentCount;

  /// 모둠 수
  final int groupCount;

  /// 평균 개인 과제 성공률 (%)
  final double avgIndividualSuccess;

  /// 평균 단체 과제 성공률 (%)
  final double avgGroupSuccess;

  ClassProgressSummary({
    required this.classId,
    required this.studentCount,
    required this.groupCount,
    required this.avgIndividualSuccess,
    required this.avgGroupSuccess,
  });

  /// 학생 목록으로부터 학급 요약 정보 생성
  factory ClassProgressSummary.fromStudents(
      String classId, List<StudentProgress> students) {
    if (students.isEmpty) {
      return ClassProgressSummary(
        classId: classId,
        studentCount: 0,
        groupCount: 0,
        avgIndividualSuccess: 0,
        avgGroupSuccess: 0,
      );
    }

    // 모둠 수 계산
    final groups = students.map((s) => s.group).toSet();

    // 개인/단체 성공률 계산
    double totalIndividualSuccess = 0;
    double totalGroupSuccess = 0;

    for (var student in students) {
      totalIndividualSuccess += student.individualSuccessCount;
      totalGroupSuccess += student.groupSuccessCount;
    }

    // 평균 성공률 계산 (총 과제 수 기준)
    final double avgIndividual =
        totalIndividualSuccess / (students.length * 6) * 100;
    final double avgGroup = totalGroupSuccess / (students.length * 6) * 100;

    return ClassProgressSummary(
      classId: classId,
      studentCount: students.length,
      groupCount: groups.length,
      avgIndividualSuccess: avgIndividual,
      avgGroupSuccess: avgGroup,
    );
  }
}

/// 모둠 자격 상태 모델
class QualificationStatus {
  /// 단체줄넘기 자격 충족 여부
  final bool qualified;

  /// 현재 성공 횟수
  final int count;

  /// 필요한 성공 횟수
  final int needed;

  QualificationStatus({
    required this.qualified,
    required this.count,
    required this.needed,
  });

  /// 자격 충족까지 남은 횟수
  int get remaining => needed - count;

  /// 자격 충족 진행률 (%)
  double get progress => needed > 0 ? (count / needed * 100) : 0;
}
