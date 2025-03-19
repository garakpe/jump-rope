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

      // 이전 버전 호환성을 위한 비교 (학번 앞 3자리)
      if (model1.studentId.length >= 3 && model2.studentId.length >= 3) {
        try {
          final classCode1 = model1.studentId.substring(0, 3);
          final classCode2 = model2.studentId.substring(0, 3);
          return classCode1 == classCode2;
        } catch (e) {
          print('학번 비교 오류: $e');
        }
      }
    }

    // 정보가 부족해 비교 불가능
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
              String studentClassNum = student.classNum.length == 1
                  ? student.classNum.padLeft(2, '0')
                  : student.classNum;

              // 이미 grade는 호출 측에서 패딩되어 전달됨
              // 같은 학급인 경우 또는 grade가 비어있는 경우 결과에 포함
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
            .where((student) => student.group == groupId.toString())
            .toList();
      }

      return result;
    } catch (e) {
      print('모둠원 통합 조회 오류: $e');
      return [];
    }
  }

  // 과제 상태 업데이트
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
    if (_studentsByClass.containsKey(student.grade)) {
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

  // 학급 과제 상태 실시간 조회
  Stream<List<FirebaseStudentModel>> getClassTasksStream(String grade) {
    final streamController = StreamController<List<FirebaseStudentModel>>();

    try {
      // classNum으로 먼저 조회
      final subscription = _firestore
          .collection('students')
          .where('classNum', isEqualTo: grade)
          .snapshots()
          .listen(
        (snapshot) {
          final students = snapshot.docs
              .map((doc) => FirebaseStudentModel.fromFirestore(doc))
              .toList();

          streamController.add(students);

          // 로컬 캐시 업데이트
          _studentsByClass[grade] = students;
          for (var student in students) {
            _students[student.id] = student;
          }
        },
        onError: (error) {
          // 로컬 캐시 사용 또는 grade으로 다시 시도
          if (_studentsByClass.containsKey(grade)) {
            streamController.add(_studentsByClass[grade]!);
          } else {
            // grade으로 다시 시도
            _firestore
                .collection('students')
                .where('grade', isEqualTo: grade)
                .get()
                .then((gradeSnapshot) {
              if (gradeSnapshot.docs.isNotEmpty) {
                final gradeStudents = gradeSnapshot.docs
                    .map((doc) => FirebaseStudentModel.fromFirestore(doc))
                    .toList();

                streamController.add(gradeStudents);

                // 로컬 캐시 업데이트
                _studentsByClass[grade] = gradeStudents;
                for (var student in gradeStudents) {
                  _students[student.id] = student;
                }
              } else {
                streamController.add([]);
              }
            }).catchError((e) {
              streamController.add([]);
            });
          }
        },
      );

      // 컨트롤러 종료 시 구독 취소
      streamController.onCancel = () {
        subscription.cancel();
      };

      return streamController.stream;
    } catch (e) {
      // Firebase 연결 실패 시 로컬 백업 로직 사용
      return Stream.value(_studentsByClass[grade] ?? []);
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

  // 모둠의 단체줄넘기 자격 확인
  Future<bool> canStartGroupActivities(String grade, String groupId) async {
    try {
      // 모둠 학생들 가져오기
      QuerySnapshot students = await _firestore
          .collection('students')
          .where('grade', isEqualTo: grade)
          .where('group', isEqualTo: groupId)
          .get();

      int totalSuccesses = 0;
      int totalStudents = students.docs.length;

      if (totalStudents == 0) return false;

      // 개인 과제 성공 횟수 계산
      for (var doc in students.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        Map<String, dynamic> individualTasks = data['individualTasks'] ?? {};

        for (var task in individualTasks.entries) {
          Map<String, dynamic> taskData = task.value as Map<String, dynamic>;
          if (taskData['completed'] == true) {
            totalSuccesses++;
          }
        }
      }

      // 자격 조건: 전체 학생 수 × 5회 이상 성공
      int requiredSuccesses = totalStudents * 5;
      return totalSuccesses >= requiredSuccesses;
    } catch (e) {
      // Firebase 연결 실패 시 로컬 백업 로직 사용
      final students = _studentsByClass[grade] ?? [];
      final groupStudents = students.where((s) => s.group == groupId).toList();

      int totalSuccesses = 0;
      int totalStudents = groupStudents.length;

      if (totalStudents == 0) return false;

      // 개인 과제 성공 횟수 계산
      for (var student in groupStudents) {
        for (var task in student.individualTasks.entries) {
          Map<String, dynamic> taskData = task.value as Map<String, dynamic>;
          if (taskData['completed'] == true) {
            totalSuccesses++;
          }
        }
      }

      // 자격 조건: 전체 학생 수 × 5회 이상 성공
      int requiredSuccesses = totalStudents * 5;
      return totalSuccesses >= requiredSuccesses;
    }
  }
}
