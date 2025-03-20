// lib/services/task_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/firebase_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 로컬 구현을 위한 데이터 (Firebase 연결 실패 시 백업용)
  final Map<String, FirebaseStudentModel> _students = {};
  final Map<String, List<FirebaseStudentModel>> _studentsByClass = {};
  final List<Map<String, dynamic>> _pendingUpdates = [];

  // 상수 정의
  static const int _defaultTimeout = 5; // 기본 타임아웃 (초)
  static const int _maxRetries = 2; // 최대 재시도 횟수

  TaskService() {
    _initializeSampleData();
    loadPendingUpdates();
  }

  // 로컬 캐시에서 학생 데이터 조회
  FirebaseStudentModel? getCachedStudentData(String studentId) {
    return _students[studentId];
  }

  bool areStudentsInSameClass(String id1, String id2) {
    // 1. id가 같으면 당연히 같은 학생
    if (id1 == id2) return true;

    // 2. 캐시된 Firebase 모델을 활용한 비교
    final model1 = _students[id1];
    final model2 = _students[id2];

    if (model1 != null && model2 != null) {
      // classNum이 있으면 그것을 비교
      if (model1.classNum.isNotEmpty && model2.classNum.isNotEmpty) {
        return model1.classNum == model2.classNum;
      }

      // grade이 있으면 그것을 비교
      if (model1.grade.isNotEmpty && model2.grade.isNotEmpty) {
        return model1.grade == model2.grade;
      }
    }

    return false;
  }

  // 초기화 함수
  void _initializeSampleData() {
    _students.clear();
    _studentsByClass.clear();
  }

  // 보류 중인 업데이트 로드
  Future<void> loadPendingUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? pendingUpdatesJson = prefs.getString('pendingTaskUpdates');

      if (pendingUpdatesJson != null) {
        final List<dynamic> decoded = jsonDecode(pendingUpdatesJson);
        _pendingUpdates.clear();
        _pendingUpdates.addAll(decoded.cast<Map<String, dynamic>>());
      }
    } catch (e) {
      print('보류 중인 업데이트 로드 오류: $e');
    }
  }

  // 보류 중인 업데이트 저장
  Future<void> _savePendingUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(_pendingUpdates);
      await prefs.setString('pendingTaskUpdates', encoded);
    } catch (e) {
      print('보류 중인 업데이트 저장 오류: $e');
    }
  }

  // Firebase 작업 재시도 유틸리티 함수
  Future<T> _retryOperation<T>(Future<T> Function() operation,
      {int maxRetries = _maxRetries,
      int timeoutSeconds = _defaultTimeout}) async {
    int retryCount = 0;

    while (true) {
      try {
        return await operation().timeout(Duration(seconds: timeoutSeconds));
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          throw Exception('여러 번 시도 후에도 작업을 완료하지 못했습니다: $e');
        }
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
  }

  // 학생 데이터 직접 가져오기
  Future<FirebaseStudentModel?> getStudentDataDirectly(String studentId) async {
    if (studentId.isEmpty) {
      print('잘못된 학생 ID: 빈 문자열');
      return null;
    }

    try {
      // 학생 ID로 조회 시도
      QuerySnapshot querySnapshot = await _retryOperation(() async {
        // 먼저 studentId 필드로 검색
        QuerySnapshot qs = await _firestore
            .collection('students')
            .where('studentId', isEqualTo: studentId)
            .limit(1)
            .get();

        // 결과가 없으면 id 필드로 검색
        if (qs.docs.isEmpty) {
          qs = await _firestore
              .collection('students')
              .where('id', isEqualTo: studentId)
              .limit(1)
              .get();
        }

        return qs;
      });

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      // 학생 정보 파싱
      final student =
          FirebaseStudentModel.fromFirestore(querySnapshot.docs.first);

      // 로컬 캐시 업데이트
      _students[student.id] = student;

      return student;
    } catch (e) {
      // Firebase 연결 오류 시 로컬 데이터 반환
      if (_students.containsKey(studentId)) {
        return _students[studentId];
      }

      // 학번으로 로컬 캐시에서 검색
      for (var student in _students.values) {
        if (student.studentId == studentId) {
          return student;
        }
      }

      throw Exception('학생 데이터를 가져올 수 없습니다: $e');
    }
  }

  // 모둠원 데이터 스트림으로 가져오기 (실시간 구독)
  Stream<List<FirebaseStudentModel>> getGroupMembersStream(
      String groupId, String classNum) {
    final streamController = StreamController<List<FirebaseStudentModel>>();

    if (groupId.isEmpty) {
      streamController.add([]);
      return streamController.stream;
    }

    try {
      // 그룹 ID와 classNum으로 학생들 조회
      final subscription = _firestore
          .collection('students')
          .where('group', isEqualTo: groupId)
          .snapshots()
          .listen(
        (snapshot) {
          List<FirebaseStudentModel> students = [];

          for (var doc in snapshot.docs) {
            try {
              final student = FirebaseStudentModel.fromFirestore(doc);

              // 메모리에 캐시
              _students[student.id] = student;

              // classNum 기반 필터링
              String studentClassNum =
                  student.classNum.isEmpty ? student.grade : student.classNum;

              if (classNum.isEmpty || studentClassNum == classNum) {
                students.add(student);
              }
            } catch (e) {
              print('모둠원 데이터 파싱 오류: $e');
            }
          }

          streamController.add(students);
        },
        onError: (error) {
          print('모둠원 스트림 오류: $error');
          // 로컬 캐시에서 결과 제공
          try {
            final cachedStudents = _students.values
                .where((student) =>
                    student.group == groupId &&
                    (student.classNum == classNum ||
                        (student.classNum.isEmpty &&
                            student.grade == classNum)))
                .toList();
            streamController.add(cachedStudents);
          } catch (e) {
            streamController.addError('캐시된 모둠원 데이터 조회 오류: $e');
            streamController.add([]);
          }
        },
      );

      // 컨트롤러 종료 시 구독 취소
      streamController.onCancel = () {
        subscription.cancel();
      };

      return streamController.stream;
    } catch (e) {
      // 오류 발생시 빈 목록 반환
      print('모둠원 스트림 설정 오류: $e');
      streamController.add([]);
      return streamController.stream;
    }
  }

  // 기존 단일 조회 메서드 (이전 코드와의 호환성 유지)
  Future<List<FirebaseStudentModel>> getGroupMembers(
      String groupId, String classNum) async {
    if (groupId.isEmpty) {
      return [];
    }

    try {
      List<FirebaseStudentModel> result = [];

      try {
        // 그룹 ID로 학생들 조회
        final QuerySnapshot querySnapshot = await _retryOperation(() async {
          return await _firestore
              .collection('students')
              .where('group', isEqualTo: groupId)
              .get();
        }, timeoutSeconds: 10);

        if (querySnapshot.docs.isNotEmpty) {
          for (var doc in querySnapshot.docs) {
            try {
              final student = FirebaseStudentModel.fromFirestore(doc);

              // 메모리에 캐시
              _students[student.id] = student;

              // 학급 비교 시 형식 통일
              String studentClassNum =
                  student.classNum.isEmpty ? student.grade : student.classNum;

              // 같은 학급인 경우 결과에 포함
              if (classNum.isEmpty || studentClassNum == classNum) {
                result.add(student);
              }
            } catch (e) {
              print('학생 파싱 오류: $e');
            }
          }
        }
      } catch (e) {
        // 로컬 캐시에서 조회 시도
        result = _students.values
            .where((student) =>
                student.group == groupId &&
                (student.classNum == classNum ||
                    (student.classNum.isEmpty && student.grade == classNum)))
            .toList();
      }

      return result;
    } catch (e) {
      print('모둠원 통합 조회 오류: $e');
      return [];
    }
  }

  // 과제 상태 업데이트 (로컬 캐시도 즉시 업데이트)
  Future<void> updateTaskStatus(String studentId, String taskName,
      bool isCompleted, bool isGroupTask) async {
    final taskPath = isGroupTask ? 'groupTasks' : 'individualTasks';

    try {
      // 현재 상태 확인
      DocumentSnapshot studentDoc =
          await _firestore.collection('students').doc(studentId).get();

      if (!studentDoc.exists) {
        throw Exception("학생 정보를 찾을 수 없습니다");
      }

      Map<String, dynamic>? studentData =
          studentDoc.data() as Map<String, dynamic>?;
      if (studentData == null) {
        throw Exception("학생 데이터가 null입니다");
      }

      Map<String, dynamic> tasks =
          (studentData[taskPath] as Map<String, dynamic>?) ?? {};

      // 완료 날짜 결정
      String? completedDate;

      if (tasks.containsKey(taskName)) {
        Map<String, dynamic>? taskData =
            tasks[taskName] as Map<String, dynamic>?;
        if (taskData != null && taskData['completed'] == true && isCompleted) {
          // 이미 완료된 과제라면 기존 날짜 유지
          completedDate = taskData['completedDate']?.toString();
        }
      }

      // 새로운 완료 날짜 생성 또는 취소
      if (isCompleted && completedDate == null) {
        completedDate = DateTime.now().toIso8601String();
      } else if (!isCompleted) {
        completedDate = null;
      }

      // 필드 업데이트 데이터 준비
      Map<String, dynamic> updateData = {
        '$taskPath.$taskName': {
          'completed': isCompleted,
          'completedDate': completedDate,
        }
      };

      // Firebase 업데이트
      await _firestore.collection('students').doc(studentId).update(updateData);

      // 로컬 캐시도 업데이트
      _updateLocalStudentData(
          studentId, taskName, isCompleted, completedDate, isGroupTask);
    } catch (e) {
      // 오류 발생 시 보류 중인 업데이트 목록에 추가
      _pendingUpdates.add({
        'studentId': studentId,
        'taskName': taskName,
        'isCompleted': isCompleted,
        'isGroupTask': isGroupTask,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await _savePendingUpdates();
      throw Exception("Firebase 업데이트 실패: $e");
    }
  }

  // 로컬 데이터 업데이트 헬퍼 메서드
  void _updateLocalStudentData(String studentId, String taskName,
      bool isCompleted, String? completedDate, bool isGroupTask) {
    if (!_students.containsKey(studentId)) return;

    final student = _students[studentId]!;

    // 깊은 복사로 데이터 변경 준비
    final Map<String, dynamic> updatedIndividualTasks =
        Map<String, dynamic>.from(student.individualTasks ?? {});
    final Map<String, dynamic> updatedGroupTasks =
        Map<String, dynamic>.from(student.groupTasks ?? {});

    // 적절한 맵 업데이트
    if (isGroupTask) {
      updatedGroupTasks[taskName] = {
        'completed': isCompleted,
        'completedDate': completedDate,
      };
    } else {
      updatedIndividualTasks[taskName] = {
        'completed': isCompleted,
        'completedDate': completedDate,
      };
    }

    // 업데이트된 학생 객체 생성
    final updatedStudent = FirebaseStudentModel(
      id: student.id,
      name: student.name,
      studentId: student.studentId,
      grade: student.grade,
      classNum: student.classNum,
      studentNum: student.studentNum,
      group: student.group,
      individualTasks: updatedIndividualTasks,
      groupTasks: updatedGroupTasks,
      attendance: student.attendance,
    );

    // 캐시 업데이트
    _students[studentId] = updatedStudent;

    // 학급별 캐시도 업데이트
    if (_studentsByClass.containsKey(student.classNum)) {
      final index = _studentsByClass[student.classNum]!
          .indexWhere((s) => s.id == studentId);
      if (index >= 0) {
        _studentsByClass[student.classNum]![index] = updatedStudent;
      }
    } else if (_studentsByClass.containsKey(student.grade)) {
      final index =
          _studentsByClass[student.grade]!.indexWhere((s) => s.id == studentId);
      if (index >= 0) {
        _studentsByClass[student.grade]![index] = updatedStudent;
      }
    }
  }

  // 학생의 과제 진도 실시간 조회
  Stream<FirebaseStudentModel> getStudentTasksStream(String studentId) {
    final streamController = StreamController<FirebaseStudentModel>();

    try {
      // Firestore 구독 설정
      final subscription = _firestore
          .collection('students')
          .doc(studentId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          final student = FirebaseStudentModel.fromFirestore(snapshot);
          streamController.add(student);

          // 로컬 캐시 업데이트
          _students[studentId] = student;
        } else {
          streamController.addError("학생 정보를 찾을 수 없습니다");
        }
      }, onError: (error) {
        // 오류 발생 시 로컬 데이터 사용
        if (_students.containsKey(studentId)) {
          streamController.add(_students[studentId]!);
        } else {
          streamController.addError("데이터 연결 오류: $error");
        }
      });

      // 컨트롤러 종료 시 구독 취소
      streamController.onCancel = () {
        subscription.cancel();
      };

      return streamController.stream;
    } catch (e) {
      // Firebase 연결 실패 시 로컬 백업 로직 사용
      if (_students.containsKey(studentId)) {
        return Stream.value(_students[studentId]!);
      }

      return Stream.value(FirebaseStudentModel(
        id: 'dummy',
        name: 'Not Found',
        studentId: 'not_found',
        grade: '0',
        classNum: '0',
        studentNum: 'not_fond',
        group: '0',
      ));
    }
  }

  // 학급 과제 상태 실시간 조회 (필드 기반 개선)
  Stream<List<FirebaseStudentModel>> getClassTasksStream(
      String classIdentifier) {
    final streamController = StreamController<List<FirebaseStudentModel>>();

    try {
      // classNum으로 먼저 조회
      final subscription = _firestore
          .collection('students')
          .where('classNum', isEqualTo: classIdentifier)
          .snapshots()
          .listen(
        (snapshot) {
          final students = snapshot.docs
              .map((doc) => FirebaseStudentModel.fromFirestore(doc))
              .toList();

          streamController.add(students);

          // 로컬 캐시 업데이트
          _studentsByClass[classIdentifier] = students;
          for (var student in students) {
            _students[student.id] = student;
          }
        },
        onError: (error) {
          print('classNum으로 학급 데이터 조회 실패: $error - grade로 재시도합니다.');

          // grade로 다시 시도
          _firestore
              .collection('students')
              .where('grade', isEqualTo: classIdentifier)
              .get()
              .then((gradeSnapshot) {
            if (gradeSnapshot.docs.isNotEmpty) {
              final gradeStudents = gradeSnapshot.docs
                  .map((doc) => FirebaseStudentModel.fromFirestore(doc))
                  .toList();

              streamController.add(gradeStudents);

              // 로컬 캐시 업데이트
              _studentsByClass[classIdentifier] = gradeStudents;
              for (var student in gradeStudents) {
                _students[student.id] = student;
              }
            } else {
              // 로컬 캐시 시도
              if (_studentsByClass.containsKey(classIdentifier)) {
                streamController.add(_studentsByClass[classIdentifier]!);
              } else {
                streamController.add([]);
              }
            }
          }).catchError((e) {
            // 로컬 캐시 시도
            if (_studentsByClass.containsKey(classIdentifier)) {
              streamController.add(_studentsByClass[classIdentifier]!);
            } else {
              streamController.add([]);
            }
          });
        },
      );

      // 컨트롤러 종료 시 구독 취소
      streamController.onCancel = () {
        subscription.cancel();
      };

      return streamController.stream;
    } catch (e) {
      // Firebase 연결 실패 시 로컬 백업 로직 사용
      return Stream.value(_studentsByClass[classIdentifier] ?? []);
    }
  }

  // 네트워크 상태 확인
  Future<bool> isNetworkAvailable() async {
    try {
      // Firebase에 간단한 요청을 보내서 연결 확인
      await _firestore
          .collection('app_settings')
          .doc('status')
          .get()
          .timeout(const Duration(seconds: 3));
      return true;
    } catch (e) {
      return false;
    }
  }

  // 오프라인 변경 사항 동기화
  Future<void> syncOfflineChanges() async {
    if (_pendingUpdates.isEmpty) return;

    // 보류 중인 항목을 복사하고 목록 초기화
    final updatesCopy = List<Map<String, dynamic>>.from(_pendingUpdates);
    _pendingUpdates.clear();
    await _savePendingUpdates();

    final List<Map<String, dynamic>> failedUpdates = [];

    // 각 업데이트 항목 처리
    for (final update in updatesCopy) {
      try {
        final studentId = update['studentId'] as String;
        final taskName = update['taskName'] as String;
        final isCompleted = update['isCompleted'] as bool;
        final isGroupTask = update['isGroupTask'] as bool;
        final taskPath = isGroupTask ? 'groupTasks' : 'individualTasks';

        // Firebase에 업데이트
        await _firestore.collection('students').doc(studentId).update({
          '$taskPath.$taskName': {
            'completed': isCompleted,
            'completedDate': isCompleted ? update['timestamp'] : null,
          }
        });
      } catch (e) {
        failedUpdates.add(update);
      }
    }

    // 실패한 업데이트는 다시 목록에 추가
    if (failedUpdates.isNotEmpty) {
      _pendingUpdates.addAll(failedUpdates);
      await _savePendingUpdates();
    }
  }
}
