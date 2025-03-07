// lib/models/firebase_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseUserModel {
  final String uid;
  final String name;
  final String email;
  final bool isTeacher;
  final String? teacherCode;

  FirebaseUserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.isTeacher = false,
    this.teacherCode,
  });

  factory FirebaseUserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return FirebaseUserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      isTeacher: data['isTeacher'] ?? false,
      teacherCode: data['teacherCode'],
    );
  }

  // 로컬 구현
  factory FirebaseUserModel.fromMap(Map<String, dynamic> data, String id) {
    return FirebaseUserModel(
      uid: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      isTeacher: data['isTeacher'] ?? false,
      teacherCode: data['teacherCode'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'isTeacher': isTeacher,
      'teacherCode': teacherCode,
    };
  }
}

// lib/models/firebase_models.dart에서 FirebaseStudentModel 클래스 개선

class FirebaseStudentModel {
  final String id;
  final String name;
  final String studentId;
  final String className;
  final String classNum; // 추가: 반 정보
  final int group;
  final Map<String, dynamic> individualTasks;
  final Map<String, dynamic> groupTasks;
  final bool attendance;

  FirebaseStudentModel({
    required this.id,
    required this.name,
    required this.studentId,
    required this.className,
    this.classNum = '', // 기본값 추가
    required this.group,
    this.individualTasks = const {},
    this.groupTasks = const {},
    this.attendance = true,
  });

  // 타임스탬프 처리 개선
  factory FirebaseStudentModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // individualTasks와 groupTasks 처리 개선
    Map<String, dynamic> processedIndividualTasks = {};
    Map<String, dynamic> processedGroupTasks = {};

    // individualTasks 처리
    Map<String, dynamic> rawIndividualTasks = data['individualTasks'] ?? {};
    rawIndividualTasks.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        // Timestamp 처리
        var completedDate = value['completedDate'];
        if (completedDate is Timestamp) {
          completedDate = completedDate.toDate().toIso8601String();
        }

        processedIndividualTasks[key] = {
          'completed': value['completed'] ?? false,
          'completedDate': completedDate,
        };
      } else {
        processedIndividualTasks[key] = {
          'completed': false,
          'completedDate': null,
        };
      }
    });

    // groupTasks 처리 (동일한 방식)
    Map<String, dynamic> rawGroupTasks = data['groupTasks'] ?? {};
    rawGroupTasks.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        // Timestamp 처리
        var completedDate = value['completedDate'];
        if (completedDate is Timestamp) {
          completedDate = completedDate.toDate().toIso8601String();
        }

        processedGroupTasks[key] = {
          'completed': value['completed'] ?? false,
          'completedDate': completedDate,
        };
      } else {
        processedGroupTasks[key] = {
          'completed': false,
          'completedDate': null,
        };
      }
    });
    return FirebaseStudentModel(
      id: doc.id,
      name: data['name'] ?? '',
      studentId: data['studentId'] ?? '',
      className: data['className'] ?? '',
      classNum: data['classNum'] ?? '', // 파싱 추가
      group: data['group'] ?? 1,
      individualTasks: data['individualTasks'] ?? {},
      groupTasks: data['groupTasks'] ?? {},
      attendance: data['attendance'] ?? true,
    );
  }

  FirebaseStudentModel copyWith({
    String? id,
    String? name,
    String? studentId,
    String? className,
    int? group,
    Map<String, dynamic>? individualTasks,
    Map<String, dynamic>? groupTasks,
    bool? attendance,
  }) {
    return FirebaseStudentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      studentId: studentId ?? this.studentId,
      className: className ?? this.className,
      group: group ?? this.group,
      individualTasks: individualTasks ?? this.individualTasks,
      groupTasks: groupTasks ?? this.groupTasks,
      attendance: attendance ?? this.attendance,
    );
  }

  // 로컬 구현
  factory FirebaseStudentModel.fromMap(Map<String, dynamic> data, String id) {
    return FirebaseStudentModel(
      id: id,
      name: data['name'] ?? '',
      studentId: data['studentId'] ?? '',
      className: data['className'] ?? '',
      group: data['group'] ?? 1,
      individualTasks: data['individualTasks'] ?? {},
      groupTasks: data['groupTasks'] ?? {},
      attendance: data['attendance'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'studentId': studentId,
      'className': className,
      'group': group,
      'individualTasks': individualTasks,
      'groupTasks': groupTasks,
      'attendance': attendance,
    };
  }
}

class FirebaseReflectionModel {
  final String id;
  final String studentId;
  final String studentName;
  final String className;
  final int group;
  final int week;
  final List<String> questions;
  final Map<String, String> answers;
  final DateTime submittedDate;

  FirebaseReflectionModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.group,
    required this.week,
    required this.questions,
    required this.answers,
    required this.submittedDate,
  });

  factory FirebaseReflectionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // submittedDate가 null이거나 타입이 맞지 않는 경우 기본값 제공
    DateTime date = DateTime.now();
    if (data['submittedDate'] != null) {
      if (data['submittedDate'] is Timestamp) {
        date = (data['submittedDate'] as Timestamp).toDate();
      }
    }

    return FirebaseReflectionModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      className: data['className'] ?? '',
      group: data['group'] ?? 0,
      week: data['week'] ?? 0,
      questions: List<String>.from(data['questions'] ?? []),
      answers: Map<String, String>.from(data['answers'] ?? {}),
      submittedDate: date,
    );
  }

  // 로컬 구현
  factory FirebaseReflectionModel.fromMap(
      Map<String, dynamic> data, String id) {
    return FirebaseReflectionModel(
      id: id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      className: data['className'] ?? '',
      group: data['group'] ?? 0,
      week: data['week'] ?? 0,
      questions: List<String>.from(data['questions'] ?? []),
      answers: Map<String, String>.from(data['answers'] ?? {}),
      submittedDate: data['submittedDate'] is DateTime
          ? data['submittedDate']
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'className': className,
      'group': group,
      'week': week,
      'questions': questions,
      'answers': answers,
      'submittedDate': Timestamp.fromDate(submittedDate),
    };
  }
}

// 기존 ReflectionSubmission 클래스와 호환되는 형태로 추가
class ReflectionSubmission {
  final String studentId;
  final int reflectionId;
  final int week;
  final Map<String, String> answers;
  final DateTime submittedDate;
  final String studentName;
  final String className;
  final int group;

  ReflectionSubmission({
    required this.studentId,
    required this.reflectionId,
    required this.week,
    required this.answers,
    required this.submittedDate,
    this.studentName = '',
    this.className = '',
    this.group = 0,
  });
}
