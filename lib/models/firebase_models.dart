// lib/models/firebase_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// 성찰 보고서 상태 열거형 추가
enum ReflectionStatus {
  notSubmitted, // 미제출
  submitted, // 제출됨
  rejected, // 반려됨
  accepted // 승인됨
}

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

  factory FirebaseUserModel.fromMap(Map<String, dynamic> data, String id) {
    return FirebaseUserModel(
      uid: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      isTeacher: data['isTeacher'] ?? false,
      teacherCode: data['teacherCode'],
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'isTeacher': isTeacher,
        'teacherCode': teacherCode,
      };
}

class FirebaseStudentModel {
  final String id;
  final String name;
  final String studentId;
  final String className;
  final String classNum;
  final int group;
  final Map<String, dynamic> individualTasks;
  final Map<String, dynamic> groupTasks;
  final bool attendance;

  FirebaseStudentModel({
    required this.id,
    required this.name,
    required this.studentId,
    required this.className,
    this.classNum = '',
    required this.group,
    this.individualTasks = const {},
    this.groupTasks = const {},
    this.attendance = true,
  });

  factory FirebaseStudentModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Process individual tasks
    Map<String, dynamic> processedIndividualTasks = {};
    Map<String, dynamic> rawIndividualTasks = data['individualTasks'] ?? {};
    rawIndividualTasks.forEach((key, value) {
      if (value is Map<String, dynamic>) {
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

    // Process group tasks
    Map<String, dynamic> processedGroupTasks = {};
    Map<String, dynamic> rawGroupTasks = data['groupTasks'] ?? {};
    rawGroupTasks.forEach((key, value) {
      if (value is Map<String, dynamic>) {
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
      classNum: data['classNum'] ?? '',
      group: data['group'] ?? 1,
      individualTasks: processedIndividualTasks,
      groupTasks: processedGroupTasks,
      attendance: data['attendance'] ?? true,
    );
  }

  factory FirebaseStudentModel.fromMap(Map<String, dynamic> data, String id) {
    return FirebaseStudentModel(
      id: id,
      name: data['name'] ?? '',
      studentId: data['studentId'] ?? '',
      className: data['className'] ?? '',
      classNum: data['classNum'] ?? '',
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
    String? classNum,
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
      classNum: classNum ?? this.classNum,
      group: group ?? this.group,
      individualTasks: individualTasks ?? this.individualTasks,
      groupTasks: groupTasks ?? this.groupTasks,
      attendance: attendance ?? this.attendance,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'studentId': studentId,
        'className': className,
        'classNum': classNum,
        'group': group,
        'individualTasks': individualTasks,
        'groupTasks': groupTasks,
        'attendance': attendance,
      };
}

class FirebaseReflectionModel {
  final String id;
  final String studentId;
  final String studentName;
  final String className;
  final int group;
  final int week; // 하위 호환성을 위해 유지, 사용하지 않음
  final int reflectionId; // 추가: 성찰 유형 ID (1:초기, 2:중기, 3:최종)
  final List<String> questions;
  final Map<String, String> answers;
  final DateTime submittedDate;
  // 상태 관련 필드
  final ReflectionStatus status;
  final String? rejectionReason;
  final DateTime? reviewedDate;
  final String? teacherNote;
  final Map<String, double>? questionRatings; // 각 질문별 평가 점수

  FirebaseReflectionModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.group,
    required this.week, // 하위 호환성을 위해 유지
    this.reflectionId = 0, // 기본값 설정 (이전 데이터 호환용)
    required this.questions,
    required this.answers,
    required this.submittedDate,
    this.status = ReflectionStatus.submitted,
    this.rejectionReason,
    this.reviewedDate,
    this.teacherNote,
    this.questionRatings,
  });

  factory FirebaseReflectionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // 날짜 처리
    DateTime submittedDate = DateTime.now();
    if (data['submittedDate'] != null && data['submittedDate'] is Timestamp) {
      submittedDate = (data['submittedDate'] as Timestamp).toDate();
    }

    DateTime? reviewedDate;
    if (data['reviewedDate'] != null && data['reviewedDate'] is Timestamp) {
      reviewedDate = (data['reviewedDate'] as Timestamp).toDate();
    }

    // 상태 문자열을 열거형으로 변환
    ReflectionStatus status = ReflectionStatus.submitted;
    if (data['status'] != null) {
      String statusStr = data['status'] as String;
      switch (statusStr) {
        case 'notSubmitted':
          status = ReflectionStatus.notSubmitted;
          break;
        case 'submitted':
          status = ReflectionStatus.submitted;
          break;
        case 'rejected':
          status = ReflectionStatus.rejected;
          break;
        case 'accepted':
          status = ReflectionStatus.accepted;
          break;
      }
    }

    // 질문별 평가 점수 처리
    Map<String, double>? questionRatings;
    if (data['questionRatings'] != null && data['questionRatings'] is Map) {
      questionRatings = {};
      (data['questionRatings'] as Map).forEach((key, value) {
        if (value is num) {
          questionRatings![key.toString()] = value.toDouble();
        }
      });
    }

    // 성찰 유형 ID 처리 (추가)
    int reflectionId = 0;
    if (data['reflectionId'] != null && data['reflectionId'] is int) {
      reflectionId = data['reflectionId'] as int;
    } else if (data['week'] != null && data['week'] is int) {
      // 이전 데이터는 week가 1, 2, 3이었으므로 그것을 reflectionId로 활용
      reflectionId = data['week'] as int;
    }

    return FirebaseReflectionModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      className: data['className'] ?? '',
      group: data['group'] ?? 0,
      week: data['week'] ?? 0, // 하위 호환성
      reflectionId: reflectionId, // reflectionId 필드 추가
      questions: List<String>.from(data['questions'] ?? []),
      answers: Map<String, String>.from(data['answers'] ?? {}),
      submittedDate: submittedDate,
      status: status,
      rejectionReason: data['rejectionReason'],
      reviewedDate: reviewedDate,
      teacherNote: data['teacherNote'],
      questionRatings: questionRatings,
    );
  }

  factory FirebaseReflectionModel.fromMap(
      Map<String, dynamic> data, String id) {
    // 상태 문자열을 열거형으로 변환
    ReflectionStatus status = ReflectionStatus.submitted;
    if (data['status'] != null) {
      String statusStr = data['status'] as String;
      switch (statusStr) {
        case 'notSubmitted':
          status = ReflectionStatus.notSubmitted;
          break;
        case 'submitted':
          status = ReflectionStatus.submitted;
          break;
        case 'rejected':
          status = ReflectionStatus.rejected;
          break;
        case 'accepted':
          status = ReflectionStatus.accepted;
          break;
      }
    }

    // 질문별 평가 점수 처리
    Map<String, double>? questionRatings;
    if (data['questionRatings'] != null && data['questionRatings'] is Map) {
      questionRatings = {};
      (data['questionRatings'] as Map).forEach((key, value) {
        if (value is num) {
          questionRatings![key.toString()] = value.toDouble();
        }
      });
    }

    // 성찰 유형 ID 처리 (추가)
    int reflectionId = 0;
    if (data['reflectionId'] != null) {
      reflectionId = data['reflectionId'] as int;
    } else if (data['week'] != null) {
      // 이전 데이터는 week가 1, 2, 3이었으므로 그것을 reflectionId로 활용
      reflectionId = data['week'] as int;
    }

    return FirebaseReflectionModel(
      id: id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      className: data['className'] ?? '',
      group: data['group'] ?? 0,
      week: data['week'] ?? 0, // 하위 호환성
      reflectionId: reflectionId, // reflectionId 필드 추가
      questions: List<String>.from(data['questions'] ?? []),
      answers: Map<String, String>.from(data['answers'] ?? {}),
      submittedDate: data['submittedDate'] is DateTime
          ? data['submittedDate']
          : DateTime.now(),
      status: status,
      rejectionReason: data['rejectionReason'],
      reviewedDate: data['reviewedDate'],
      teacherNote: data['teacherNote'],
      questionRatings: questionRatings,
    );
  }

  Map<String, dynamic> toMap() {
    // 상태 열거형을 문자열로 변환
    String statusStr;
    switch (status) {
      case ReflectionStatus.notSubmitted:
        statusStr = 'notSubmitted';
        break;
      case ReflectionStatus.submitted:
        statusStr = 'submitted';
        break;
      case ReflectionStatus.rejected:
        statusStr = 'rejected';
        break;
      case ReflectionStatus.accepted:
        statusStr = 'accepted';
        break;
    }

    return {
      'studentId': studentId,
      'studentName': studentName,
      'className': className,
      'group': group,
      'week': week, // 하위 호환성을 위해 유지
      'reflectionId': reflectionId, // reflectionId 필드 추가
      'questions': questions,
      'answers': answers,
      'submittedDate': Timestamp.fromDate(submittedDate),
      'status': statusStr,
      'rejectionReason': rejectionReason,
      'reviewedDate':
          reviewedDate != null ? Timestamp.fromDate(reviewedDate!) : null,
      'teacherNote': teacherNote,
      'questionRatings': questionRatings,
    };
  }

  // 새로운 상태로 복사본 생성
  FirebaseReflectionModel copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? className,
    int? group,
    int? week,
    int? reflectionId,
    List<String>? questions,
    Map<String, String>? answers,
    DateTime? submittedDate,
    ReflectionStatus? status,
    String? rejectionReason,
    DateTime? reviewedDate,
    String? teacherNote,
    Map<String, double>? questionRatings,
  }) {
    return FirebaseReflectionModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      className: className ?? this.className,
      group: group ?? this.group,
      week: week ?? this.week,
      reflectionId: reflectionId ?? this.reflectionId,
      questions: questions ?? this.questions,
      answers: answers ?? this.answers,
      submittedDate: submittedDate ?? this.submittedDate,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      reviewedDate: reviewedDate ?? this.reviewedDate,
      teacherNote: teacherNote ?? this.teacherNote,
      questionRatings: questionRatings ?? this.questionRatings,
    );
  }
}

// lib/models/firebase_models.dart에서 ReflectionSubmission 클래스 업데이트

class ReflectionSubmission {
  final String id; // ID 필드 추가
  final String studentId;
  final int reflectionId;
  final int week;
  final Map<String, String> answers;
  final DateTime submittedDate;
  final String studentName;
  final String className;
  final int group;
  final ReflectionStatus status;
  final String? rejectionReason;

  ReflectionSubmission({
    this.id = '', // ID 기본값 추가
    required this.studentId,
    required this.reflectionId,
    required this.week,
    required this.answers,
    required this.submittedDate,
    this.studentName = '',
    this.className = '',
    this.group = 0,
    this.status = ReflectionStatus.submitted,
    this.rejectionReason,
  });

  // 새로운 상태로 복사본 생성
  ReflectionSubmission copyWith({
    String? id,
    String? studentId,
    int? reflectionId,
    int? week,
    Map<String, String>? answers,
    DateTime? submittedDate,
    String? studentName,
    String? className,
    int? group,
    ReflectionStatus? status,
    String? rejectionReason,
  }) {
    return ReflectionSubmission(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      reflectionId: reflectionId ?? this.reflectionId,
      week: week ?? this.week,
      answers: answers ?? this.answers,
      submittedDate: submittedDate ?? this.submittedDate,
      studentName: studentName ?? this.studentName,
      className: className ?? this.className,
      group: group ?? this.group,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}
