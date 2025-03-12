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
      classNum: classNum,
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

    DateTime date = DateTime.now();
    if (data['submittedDate'] != null && data['submittedDate'] is Timestamp) {
      date = (data['submittedDate'] as Timestamp).toDate();
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

  Map<String, dynamic> toMap() => {
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
