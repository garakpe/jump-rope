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

  TaskService() {
    _initializeSampleData();
    loadPendingUpdates();
  }

  void _initializeSampleData() {
    // 샘플 학생 데이터 생성
    final students = [
      FirebaseStudentModel(
        id: '101',
        name: '김철수',
        studentId: '12345',
        className: '1',
        classNum: '1',
        group: 1,
        individualTasks: {
          '양발모아 뛰기': {
            'completed': true,
            'completedDate': '2023-09-10 10:00:00'
          },
          '구보로 뛰기': {'completed': false, 'completedDate': null},
        },
        groupTasks: {},
        attendance: true,
      ),
      FirebaseStudentModel(
        id: '102',
        name: '홍길동',
        studentId: '67890',
        className: '1',
        classNum: '1',
        group: 2,
        individualTasks: {
          '양발모아 뛰기': {
            'completed': true,
            'completedDate': '2023-09-11 11:00:00'
          },
        },
        groupTasks: {},
        attendance: true,
      ),
    ];

    // 데이터 저장
    for (var student in students) {
      _students[student.id] = student;

      if (!_studentsByClass.containsKey(student.className)) {
        _studentsByClass[student.className] = [];
      }
      _studentsByClass[student.className]!.add(student);
    }
  }

  // 앱 시작 시 저장된 보류 중인 업데이트 로드
  Future<void> loadPendingUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? pendingUpdatesJson = prefs.getString('pendingTaskUpdates');

      if (pendingUpdatesJson != null) {
        final List<dynamic> decoded = jsonDecode(pendingUpdatesJson);
        _pendingUpdates.clear();
        _pendingUpdates.addAll(decoded.cast<Map<String, dynamic>>());

        print('보류 중인 업데이트 불러옴: ${_pendingUpdates.length}개');
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

// 5. task_service.dart의 updateTaskStatus 메서드 수정

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

      Map<String, dynamic> studentData =
          studentDoc.data() as Map<String, dynamic>;
      Map<String, dynamic>? tasks =
          studentData[taskPath] as Map<String, dynamic>?;

      // 이미 완료된 과제인지 확인
      String? completedDate;

      if (tasks != null && tasks.containsKey(taskName)) {
        Map<String, dynamic>? taskData =
            tasks[taskName] as Map<String, dynamic>?;
        if (taskData != null && taskData['completed'] == true && isCompleted) {
          // 이미 완료된 과제라면 기존 날짜 유지
          completedDate = taskData['completedDate']?.toString();
          print('기존 완료된 과제의 날짜 유지: $taskName, $completedDate');
        }
      }

      // 날짜 결정
      if (isCompleted && completedDate == null) {
        // 새로 완료하는 과제라면 현재 날짜 사용
        completedDate = DateTime.now().toIso8601String();
        print('새로운 완료 날짜 생성: $taskName, $completedDate');
      } else if (!isCompleted) {
        // 완료 취소 시
        completedDate = null;
        print('도장 취소: $taskName');
      }

      // 중요: 해당 필드만 업데이트
      Map<String, dynamic> updateData = {};
      updateData['$taskPath.$taskName'] = {
        'completed': isCompleted,
        'completedDate': completedDate,
      };

      // 해결책 7: Firebase 업데이트 시 특정 필드만 업데이트
      await _firestore.collection('students').doc(studentId).update(updateData);

      print('Firebase에 과제 상태 업데이트 성공: $studentId, $taskName, $isCompleted');
      return;
    } catch (e) {
      print('과제 상태 업데이트 오류: $e');

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

  // 로컬 데이터 업데이트 헬퍼 메서드 (코드 중복 방지)
  void _updateLocalStudentData(String studentId, String taskName,
      bool isCompleted, String? completedDate, bool isGroupTask) {
    if (!_students.containsKey(studentId)) return;

    final student = _students[studentId]!;

    // 깊은 복사로 데이터 변경 준비
    final Map<String, dynamic> updatedIndividualTasks =
        Map<String, dynamic>.from(student.individualTasks);
    final Map<String, dynamic> updatedGroupTasks =
        Map<String, dynamic>.from(student.groupTasks);

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
      className: student.className,
      classNum: student.classNum,
      group: student.group,
      individualTasks: updatedIndividualTasks,
      groupTasks: updatedGroupTasks,
      attendance: student.attendance,
    );

    // 캐시 업데이트
    _students[studentId] = updatedStudent;

    // 학급별 캐시도 업데이트
    if (_studentsByClass.containsKey(student.className)) {
      final index = _studentsByClass[student.className]!
          .indexWhere((s) => s.id == studentId);
      if (index >= 0) {
        _studentsByClass[student.className]![index] = updatedStudent;
      }
    }
  }

  // 학생의 과제 진도 실시간 조회
  Stream<FirebaseStudentModel> getStudentTasksStream(String studentId) {
    try {
      final streamController = StreamController<FirebaseStudentModel>();

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
        print('Firestore 스트림 에러: $error');
        streamController.addError("데이터 연결 오류: $error");

        // 오류 발생 시 로컬 데이터 사용
        if (_students.containsKey(studentId)) {
          streamController.add(_students[studentId]!);
        }
      });

      // 컨트롤러 종료 시 구독 취소
      streamController.onCancel = () {
        subscription.cancel();
      };

      return streamController.stream;
    } catch (e) {
      print('학생 과제 스트림 생성 오류: $e');

      // Firebase 연결 실패 시 로컬 백업 로직 사용
      if (_students.containsKey(studentId)) {
        return Stream.value(_students[studentId]!);
      }

      return Stream.value(FirebaseStudentModel(
        id: 'dummy',
        name: 'Not Found',
        studentId: 'not_found',
        className: '0',
        classNum: '0',
        group: 0,
      ));
    }
  }

// task_service.dart 파일 수정
// getClassTasksStream 메서드 수정
  Stream<List<FirebaseStudentModel>> getClassTasksStream(String className) {
    try {
      final streamController = StreamController<List<FirebaseStudentModel>>();

      print('TaskService - 학급 데이터 요청: $className'); // 디버깅 로그 추가

      // 학급 학생 목록을 실시간으로 구독
      // 중요: className과 classNum 두 가지 필드 모두 확인
      final query = _firestore.collection('students');

      // 중요: 쿼리를 수정하여 학급 번호를 문자열 또는 숫자로 처리
      final subscription =
          query.where('classNum', isEqualTo: className).snapshots().listen(
        (snapshot) {
          final students = snapshot.docs
              .map((doc) => FirebaseStudentModel.fromFirestore(doc))
              .toList();

          print(
              'TaskService - 학급 $className 데이터 로드: ${students.length}명'); // 디버깅 로그 추가

          streamController.add(students);

          // 로컬 캐시 업데이트
          _studentsByClass[className] = students;
          for (var student in students) {
            _students[student.id] = student;
          }
        },
        onError: (error) {
          print('Firestore 학급 스트림 오류: $error');

          // 오류 발생 시 로컬 데이터 사용
          if (_studentsByClass.containsKey(className)) {
            print('TaskService - 로컬 데이터 사용: $className'); // 디버깅 로그 추가
            streamController.add(_studentsByClass[className]!);
          } else {
            // classNum 필드로 찾지 못했다면, className 필드로도 시도
            print(
                'TaskService - classNum으로 찾지 못해 className으로 시도: $className'); // 디버깅 로그 추가
            _firestore
                .collection('students')
                .where('className', isEqualTo: className)
                .get()
                .then((classNameSnapshot) {
              if (classNameSnapshot.docs.isNotEmpty) {
                final classNameStudents = classNameSnapshot.docs
                    .map((doc) => FirebaseStudentModel.fromFirestore(doc))
                    .toList();

                print(
                    'TaskService - className으로 찾음: ${classNameStudents.length}명'); // 디버깅 로그 추가

                streamController.add(classNameStudents);

                // 로컬 캐시 업데이트
                _studentsByClass[className] = classNameStudents;
                for (var student in classNameStudents) {
                  _students[student.id] = student;
                }
              } else {
                print('TaskService - 학급 데이터 없음: $className'); // 디버깅 로그 추가
                streamController.add([]);
              }
            }).catchError((e) {
              print('TaskService - className 쿼리 오류: $e'); // 디버깅 로그 추가
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
      print('학급 과제 스트림 생성 오류: $e');

      // Firebase 연결 실패 시 로컬 백업 로직 사용
      print('TaskService - 로컬 백업 데이터 사용 시도: $className'); // 디버깅 로그 추가
      return Stream.value(_studentsByClass[className] ?? []);
    }
  }

  // 네트워크 상태 확인 메서드
  Future<bool> isNetworkAvailable() async {
    try {
      // Firebase에 간단한 요청을 보내서 연결 확인
      await _firestore.collection('app_settings').doc('status').get();
      return true;
    } catch (e) {
      print('네트워크 연결 확인 오류: $e');
      return false;
    }
  }

  // 오프라인 변경 사항 동기화 메서드
  Future<void> syncOfflineChanges() async {
    if (_pendingUpdates.isEmpty) return;

    print('오프라인 변경 사항 동기화 시작: ${_pendingUpdates.length}개');

    // 보류 중인 항목을 복사하고 목록 초기화 (새 오류 발생 시 다시 추가할 수 있도록)
    final updatesCopy = List<Map<String, dynamic>>.from(_pendingUpdates);
    _pendingUpdates.clear();
    await _savePendingUpdates();

    int successCount = 0;
    final List<Map<String, dynamic>> failedUpdates = [];

    // 각 업데이트 항목 처리
    for (final update in updatesCopy) {
      try {
        final studentId = update['studentId'] as String;
        final taskName = update['taskName'] as String;
        final isCompleted = update['isCompleted'] as bool;
        final isGroupTask = update['isGroupTask'] as bool;
        final taskPath = isGroupTask ? 'groupTasks' : 'individualTasks';

        // Firebase에 업데이트 시도
        await _firestore.collection('students').doc(studentId).update({
          '$taskPath.$taskName': {
            'completed': isCompleted,
            'completedDate': isCompleted
                ? update['timestamp'] // 저장된 타임스탬프 사용
                : null,
          }
        });

        successCount++;
      } catch (e) {
        print('항목 동기화 실패: $e');
        failedUpdates.add(update);
      }
    }

    // 실패한 업데이트는 다시 목록에 추가
    if (failedUpdates.isNotEmpty) {
      _pendingUpdates.addAll(failedUpdates);
      await _savePendingUpdates();
    }

    print('동기화 완료: $successCount 성공, ${failedUpdates.length} 실패');
  }

  // 모둠의 단체줄넘기 자격 확인
  Future<bool> canStartGroupActivities(String className, int groupId) async {
    try {
      // 모둠 학생들 가져오기
      QuerySnapshot students = await _firestore
          .collection('students')
          .where('className', isEqualTo: className)
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
      print("자격 조건 확인 오류: $e");

      // Firebase 연결 실패 시 로컬 백업 로직 사용
      final students = _studentsByClass[className] ?? [];
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
