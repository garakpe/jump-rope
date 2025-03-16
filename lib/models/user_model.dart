class UserModel {
  final String? name;
  final String? studentId;
  final String? grade;
  final String? classNum; // 추가: 반 정보
  final String? studentNum; // 추가된 필드
  final String? group;
  final bool isTeacher;

  UserModel({
    this.name,
    this.studentId,
    this.grade,
    this.classNum, // 생성자에 추가
    this.studentNum, // 생성자에 추가
    this.group,
    this.isTeacher = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'studentId': studentId,
      'grade': grade,
      'classNum': classNum, // map에 추가
      'group': group,
      'isTeacher': isTeacher,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      name: map['name'] as String?,
      studentId: map['studentId'] as String?,
      grade: map['grade'] as String?,
      classNum: map['classNum'] as String?, // 파싱 추가
      group: map['group'] as String?,
      isTeacher: map['isTeacher'] as bool? ?? false,
    );
  }
}
