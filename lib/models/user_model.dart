// lib/models/user_model.dart

/// 로그인된 사용자 모델
///
/// 교사 및 학생 모두에 사용되는 공통 모델입니다.
/// [isTeacher] 속성으로 교사/학생 구분을 합니다.
class UserModel {
  /// 이름
  final String? name;

  /// 학번 (학생) 또는 교사 ID (교사)
  final String? studentId;

  /// 학년 정보
  final String? className;

  /// 반 정보
  final String? classNum;

  /// 모둠 번호
  final String? group;

  /// 교사 여부
  final bool isTeacher;

  UserModel({
    this.name,
    this.studentId,
    this.className,
    this.classNum,
    this.group,
    this.isTeacher = false,
  });

  /// Map으로 변환
  ///
  /// SharedPreferences 저장 등에 사용됩니다.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'studentId': studentId,
      'className': className,
      'classNum': classNum,
      'group': group,
      'isTeacher': isTeacher,
    };
  }

  /// Map에서 모델 생성
  ///
  /// SharedPreferences에서 불러올 때 사용됩니다.
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      name: map['name'] as String?,
      studentId: map['studentId'] as String?,
      className: map['className'] as String?,
      classNum: map['classNum'] as String?,
      group: map['group'] as String?,
      isTeacher: map['isTeacher'] as bool? ?? false,
    );
  }

  /// 현재 모델을 기반으로 속성 일부만 변경한 새 인스턴스 생성
  UserModel copyWith({
    String? name,
    String? studentId,
    String? className,
    String? classNum,
    String? group,
    bool? isTeacher,
  }) {
    return UserModel(
      name: name ?? this.name,
      studentId: studentId ?? this.studentId,
      className: className ?? this.className,
      classNum: classNum ?? this.classNum,
      group: group ?? this.group,
      isTeacher: isTeacher ?? this.isTeacher,
    );
  }

  @override
  String toString() {
    return 'UserModel(name: $name, studentId: $studentId, className: $className, classNum: $classNum, group: $group, isTeacher: $isTeacher)';
  }
}
