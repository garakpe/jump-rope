// lib/providers/task_provider.dart

import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/ui_models.dart';
import '../services/task_service.dart';
import '../models/firebase_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

// task_provider.dart 파일의 최상단에 추가

// 개인 줄넘기 과제 목록 직접 정의
final List<TaskModel> _hardcodedIndividualTasks = [
  TaskModel(
      id: 1,
      name: "양발모아 뛰기",
      count: "50회",
      level: 1,
      description: "두 발을 모아 제자리에서 뛰는 기본 동작입니다. 착지 시 무릎을 살짝 굽혀 충격을 흡수하세요."),
  TaskModel(
      id: 2,
      name: "구보로 뛰기",
      count: "50회",
      level: 2,
      description: "제자리에서 구보 동작으로 뛰기를 합니다. 팔 동작을 자연스럽게 하면서 뛰어주세요."),
  TaskModel(
      id: 3,
      name: "십자뛰기",
      count: "20회",
      level: 3,
      description: "앞, 뒤, 좌, 우로 십자 모양을 그리며 뛰는 동작입니다. 방향 전환을 부드럽게 하세요."),
  TaskModel(
      id: 4,
      name: "가위바위보 뛰기",
      count: "30회",
      level: 4,
      description: "가위바위보 동작을 하면서 뛰기를 합니다. 리듬감 있게 동작을 연결하세요."),
  TaskModel(
      id: 5,
      name: "엇걸었다 풀어 뛰기",
      count: "10회",
      level: 5,
      description: "줄을 엇갈리게 넘었다가 풀어서 뛰는 고급 동작입니다. 손목 동작이 중요합니다."),
  TaskModel(
      id: 6,
      name: "이중뛰기",
      count: "10회",
      level: 6,
      description: "한 번 뛰어오를 때 줄을 두 번 돌리는 동작입니다. 높이 점프하여 시간을 확보하세요."),
];

// 단체 줄넘기 과제 목록 직접 정의
final List<TaskModel> _hardcodedGroupTasks = [
  TaskModel(
      id: 1,
      name: "2인 맞서서 뛰기",
      count: "20회",
      level: 1,
      isIndividual: false,
      description: "두 사람이 마주보고 서서 한 줄을 함께 넘습니다. 호흡을 맞추는 것이 중요합니다."),
  TaskModel(
      id: 2,
      name: "엇갈아 2인뛰기",
      count: "20회",
      level: 2,
      isIndividual: false,
      description: "두 사람이 번갈아가며 뛰는 동작입니다. 타이밍을 잘 맞춰야 합니다."),
  TaskModel(
      id: 3,
      name: "배웅통과하기",
      count: "4회",
      level: 3,
      isIndividual: false,
      description: "돌아가는 줄을 통과하여 뛰는 동작입니다. 줄의 속도와 타이밍을 잘 맞추세요."),
  TaskModel(
      id: 4,
      name: "1인 4도약 연속뛰기",
      count: "2회",
      level: 4,
      isIndividual: false,
      description: "한 사람이 4번 연속으로 도약하며 줄넘기를 하는 동작입니다. 리듬감과 균형 유지가 중요합니다."),
  TaskModel(
      id: 5,
      name: "단체줄넘기",
      count: "30회",
      level: 5,
      isIndividual: false,
      description: "여러 명이 함께 줄을 넘는 단체 활동입니다. 일정한 간격을 유지하세요."),
  TaskModel(
      id: 6,
      name: "긴 줄 연속 8자 뛰기",
      count: "40회",
      level: 6,
      isIndividual: false,
      description:
          "긴 줄을 8자 모양으로 돌리며 여러 명이 연속으로 뛰는 고급 동작입니다. 팀워크와 타이밍이 매우 중요합니다."),
];

// 학생 ID 기준 캐시
final Map<String, StudentProgress> _studentCache = {};

// 캐시 데이터 가져오기 메서드
StudentProgress? getStudentFromCache(String studentId) {
  return _studentCache[studentId];
}

class TaskProvider extends ChangeNotifier {
  final TaskService _taskService = TaskService();

  List<StudentProgress> _students = [];
  List<TaskModel> _individualTasks = [];
  List<TaskModel> _groupTasks = [];
  int _currentLevel = 1;
  int _currentWeek = 1;
  int _stampCount = 0;
  String _selectedClass = '';
  bool _isLoading = false;
  bool _isOffline = false; // 오프라인 상태 추적
  final Map<String, StudentProgress> _studentCache = {};
  bool _previousOfflineState = false; // 이전 오프라인 상태
  bool _disposed = false; // dispose 여부 추적
  String _error = '';

  // 구독 관리를 위한 변수
  StreamSubscription? _classSubscription;

  // 모둠별 도장 개수 맵
  final Map<int, int> _groupStampCounts = {};

  List<StudentProgress> get students => _students;
  List<TaskModel> get individualTasks => _individualTasks;
  List<TaskModel> get groupTasks => _groupTasks;
  int get currentLevel => _currentLevel;
  int get currentWeek => _currentWeek;
  int get stampCount => _stampCount;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  String get error => _error;
  String get selectedClass => _selectedClass;
  StudentProgress? getStudentFromCache(String studentId) {
    return _studentCache[studentId];
  }

  // 생성자에서 임시 데이터 로드
  TaskProvider() {
    _loadTasks();
    _loadSavedSettings();
    _checkNetworkStatus();
  }

  @override
  void dispose() {
    _disposed = true;
    _classSubscription?.cancel();
    super.dispose();
  }

  // 주기적으로 네트워크 상태 확인
  void _checkNetworkStatus() async {
    final wasOfflineBefore = _isOffline;
    _isOffline = !(await _taskService.isNetworkAvailable());

    // 오프라인에서 온라인으로 상태가 변경된 경우 자동 동기화
    if (wasOfflineBefore && !_isOffline) {
      print('네트워크 연결이 복구되었습니다. 데이터 동기화 중...');
      _autoSyncData();
    }

    _previousOfflineState = _isOffline;
    notifyListeners();

    // 주기적으로 상태 확인 (30초마다)
    Future.delayed(const Duration(seconds: 30), () {
      if (!_disposed) {
        _checkNetworkStatus();
      }
    });
  }

  // 자동 동기화 메서드
  Future<void> _autoSyncData() async {
    if (await _taskService.isNetworkAvailable()) {
      try {
        await _taskService.syncOfflineChanges();

        // 동기화 후 데이터 다시 로드
        if (_selectedClass.isNotEmpty) {
          _refreshData();
        }
      } catch (e) {
        print('자동 동기화 중 오류: $e');
      }
    } else {
      print('네트워크 연결 오류');
    }
  }

  // 데이터 새로고침
  Future<void> _refreshData() async {
    if (_selectedClass.isEmpty) return;

    // 기존 구독 취소
    _classSubscription?.cancel();

    // 다시 클래스 선택하여 데이터 로드
    selectClass(_selectedClass);
  }

// 다음 메서드를 TaskProvider 클래스에 추가합니다
  Future<bool> loadGroupMembers(int groupId, String className) async {
    if (groupId <= 0 || className.isEmpty) return false;

    _isLoading = true;
    notifyListeners();

    try {
      print('모둠원 데이터 로드 시작: $groupId모둠, $className학년');

      // 서비스를 통해 모둠원 불러오기
      final groupMembers =
          await _taskService.getGroupMembers(groupId, className);

      if (groupMembers.isEmpty) {
        print('모둠원 데이터가 없습니다: $groupId모둠, $className학년');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      print('모둠원 ${groupMembers.length}명 로드됨: $groupId모둠, $className학년');

      // 각 모둠원을 StudentProgress로 변환하여 저장
      for (var memberData in groupMembers) {
        // 진행 상태 데이터 변환
        final individualProgress = <String, TaskProgress>{};
        final groupProgress = <String, TaskProgress>{};

        // 개인 과제 처리
        for (var task in _individualTasks) {
          final value = memberData.individualTasks[task.name];
          final isCompleted = value is Map && value['completed'] == true;
          final completedDate =
              value is Map ? value['completedDate']?.toString() : null;

          individualProgress[task.name] = TaskProgress(
            taskName: task.name,
            isCompleted: isCompleted,
            completedDate: completedDate,
          );
        }

        // 단체 과제 처리
        for (var task in _groupTasks) {
          final value = memberData.groupTasks[task.name];
          final isCompleted = value is Map && value['completed'] == true;
          final completedDate =
              value is Map ? value['completedDate']?.toString() : null;

          groupProgress[task.name] = TaskProgress(
            taskName: task.name,
            isCompleted: isCompleted,
            completedDate: completedDate,
          );
        }

        // 학생 진도 정보 생성
        final memberProgress = StudentProgress(
          id: memberData.id,
          name: memberData.name,
          number: int.tryParse(memberData.studentId.substring(
                  memberData.studentId.length > 2
                      ? memberData.studentId.length - 2
                      : 0)) ??
              0,
          group: memberData.group,
          individualProgress: individualProgress,
          groupProgress: groupProgress,
          attendance: memberData.attendance,
        );

        // 캐시 및 전역 상태 업데이트
        _studentCache[memberData.id] = memberProgress;

        // 이미 존재하는 학생이면 업데이트, 아니면 추가
        final index = _students.indexWhere((s) => s.id == memberData.id);
        if (index >= 0) {
          final newStudents = List<StudentProgress>.from(_students);
          newStudents[index] = memberProgress;
          _students = newStudents;
        } else {
          _students = [..._students, memberProgress];
        }
      }

      // 도장 개수 재계산
      _calculateStampCount();
      _calculateGroupStampCounts();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('모둠원 데이터 로드 오류: $e');
      _error = '모둠원 데이터 로드 오류: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 저장된 설정 로드
  Future<void> _loadSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentLevel = prefs.getInt('currentLevel') ?? 1;
      _currentWeek = prefs.getInt('currentWeek') ?? 1;
      _selectedClass = prefs.getString('selectedClass') ?? '';

      // 선택된 학급이 있으면 학생 데이터 로드
      if (_selectedClass.isNotEmpty) {
        selectClass(_selectedClass);
      } else {
        _loadSampleStudents();
      }

      notifyListeners();
    } catch (e) {
      print('설정 로드 오류: $e');
    }
  }

  // 1. task_provider.dart의 _loadTasks 메서드 수정

  Future<void> _loadTasks() async {
    _isLoading = true;
    notifyListeners();

    try {
      // task_model.dart에서 가져오는 대신 하드코딩된 데이터 사용
      _individualTasks = List.from(_hardcodedIndividualTasks);
      _groupTasks = List.from(_hardcodedGroupTasks);

      print(
          '과제 데이터 로드 완료: 개인=${_individualTasks.length}, 단체=${_groupTasks.length}');

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('과제 데이터 로드 오류: $e');
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

// 변경 후
  void _loadSampleStudents() {
    // 샘플 데이터 제거
    _students = [];
    _error = '데이터를 불러올 수 없습니다. 네트워크 연결을 확인하세요.';
    _isOffline = true;
    print('샘플 데이터 대신 빈 목록 사용');
    _calculateStampCount();
    notifyListeners();
  }

  // 현재 레벨 설정
  void setCurrentLevel(int level) async {
    _currentLevel = level;

    // 설정 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentLevel', level);

    notifyListeners();
  }

  // 현재 주차 설정
  void setCurrentWeek(int week) async {
    _currentWeek = week;

    // 설정 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentWeek', week);

    notifyListeners();
  }

  // 학급 선택 및 데이터 로드
  void selectClass(String className) async {
    // 기존 구독 취소
    _classSubscription?.cancel();

    _selectedClass = className;
    _isLoading = true;
    notifyListeners();

    // 설정 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedClass', className);

    print('TaskProvider - 선택된 학급: $className');

    try {
      // 학급 데이터를 실시간으로 구독
      _classSubscription =
          _taskService.getClassTasksStream(className).listen((studentList) {
        // 데이터 변환 및 UI 업데이트
        print('TaskProvider - 학급 데이터 수신: ${studentList.length}명');
        _convertToStudentProgress(studentList);
        _isLoading = false;
        notifyListeners();
      }, onError: (error) {
        print('학급 데이터 구독 오류: $error');
        _error = 'Firebase에서 학급 데이터를 가져오는 중 오류가 발생했습니다: $error';
        _isLoading = false;
        _isOffline = true;
        notifyListeners();

        // 오류 발생 시 로컬 데이터 사용
        _loadSampleStudents();
      });
    } catch (e) {
      print('학급 데이터 구독 예외: $e');
      _isLoading = false;
      _error = e.toString();
      _isOffline = true;
      notifyListeners();

      // 오류 발생 시 샘플 데이터 로드
      _loadSampleStudents();
    }
  }

// 학생 데이터 설정 및 캐시 업데이트
  void setStudentProgress(StudentProgress student) {
    // 학생 ID가 비어있으면 처리하지 않음
    if (student.id.isEmpty) return;

    print('학생 데이터 캐시 업데이트: ${student.id}, ${student.name}');

    // 기존 학생 정보가 있는지 확인
    final index = _students.indexWhere((s) => s.id == student.id);

    if (index >= 0) {
      // 기존 학생 정보 업데이트
      final newStudents = List<StudentProgress>.from(_students);
      newStudents[index] = student;
      _students = newStudents;
    } else {
      // 새 학생 추가
      _students = [..._students, student];
    }

    // 캐시 업데이트 - 중요!
    _studentCache[student.id] = student;

    // 도장 개수 재계산
    _calculateStampCount();
    _calculateGroupStampCounts();

    notifyListeners();
  }

// 변경 후
  Future<StudentProgress?> syncStudentDataFromServer(String studentId) async {
    if (studentId.isEmpty) return null;

    // 이미 로딩 중이면 중복 작업 방지
    if (_isLoading) {
      print('이미 데이터 동기화 중입니다. 기존 요청의 완료를 기다립니다');
      return _studentCache[studentId];
    }

    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      print('서버에서 학생 데이터 동기화 시작: $studentId');

      // 서버에서 학생 데이터 가져오기 시도 (타임아웃 설정)
      FirebaseStudentModel? studentData;
      try {
        studentData = await _taskService
            .getStudentDataDirectly(studentId)
            .timeout(const Duration(seconds: 10), onTimeout: () {
          print('데이터 요청 시간 초과 (10초)');
          throw TimeoutException('서버 응답 시간 초과. 나중에 다시 시도하세요.');
        });
      } catch (e) {
        print('Firebase 데이터 가져오기 실패: $e');

        // Firebase에서 실패했지만 캐시된 데이터가 있는 경우
        final cachedStudent = _studentCache[studentId];
        if (cachedStudent != null) {
          print('로컬 캐시에서 학생 데이터 사용: $studentId');
          _error = '서버 연결 문제로 로컬 데이터를 사용합니다';
          _isLoading = false;
          notifyListeners();
          return cachedStudent;
        }

        // 캐시도 없는 경우 에러 표시
        _error = '학생 데이터를 가져올 수 없습니다: $e';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      if (studentData != null) {
        print('서버에서 가져온 학생: ${studentData.name}');

        // 개인 과제 완료 상태 확인 및 로깅
        int completedTaskCount = 0;
        studentData.individualTasks.forEach((key, value) {
          if (value is Map && value['completed'] == true) {
            completedTaskCount++;
            print('완료된 과제 확인: $key');
          }
        });
        print('서버에서 확인된 완료 과제 수: $completedTaskCount');

        // 진행 상태 데이터 변환
        final individualProgress = <String, TaskProgress>{};
        final groupProgress = <String, TaskProgress>{};

        // 모든 개인 과제에 대해 상태 초기화
        for (var task in _individualTasks) {
          final value = studentData.individualTasks[task.name];
          final isCompleted = value is Map && value['completed'] == true;
          final completedDate =
              value is Map ? value['completedDate']?.toString() : null;

          individualProgress[task.name] = TaskProgress(
            taskName: task.name,
            isCompleted: isCompleted,
            completedDate: completedDate,
          );

          print('과제 상태 설정: ${task.name}, 완료: $isCompleted, 날짜: $completedDate');
        }

        // 모든 단체 과제에 대해 상태 초기화
        for (var task in _groupTasks) {
          final value = studentData.groupTasks[task.name];
          final isCompleted = value is Map && value['completed'] == true;
          final completedDate =
              value is Map ? value['completedDate']?.toString() : null;

          groupProgress[task.name] = TaskProgress(
            taskName: task.name,
            isCompleted: isCompleted,
            completedDate: completedDate,
          );
        }

        // 학생 진도 정보 생성
        final student = StudentProgress(
          id: studentData.id,
          name: studentData.name,
          number: int.tryParse(studentData.studentId.substring(
                  studentData.studentId.length > 2
                      ? studentData.studentId.length - 2
                      : 0)) ??
              0,
          group: studentData.group,
          individualProgress: individualProgress,
          groupProgress: groupProgress,
          attendance: studentData.attendance,
        );

        // 캐시 및 전역 상태 업데이트
        _studentCache[studentId] = student;
        setStudentProgress(student);

        print('학생 데이터 동기화 완료: ${student.id}');
        print(
            '개인 과제 완료: ${individualProgress.values.where((p) => p.isCompleted).length}개');
        print(
            '단체 과제 완료: ${groupProgress.values.where((p) => p.isCompleted).length}개');

        return student;
      } else {
        // 데이터를 가져오지 못한 경우 샘플 데이터 생성
        print('학생 데이터를 가져오지 못함, 기본 데이터 사용: $studentId');

        // 기본 개인 과제 상태
        final individualProgress = <String, TaskProgress>{};
        for (var task in _individualTasks) {
          individualProgress[task.name] = TaskProgress(
            taskName: task.name,
            isCompleted: false,
          );
        }

        // 기본 단체 과제 상태
        final groupProgress = <String, TaskProgress>{};
        for (var task in _groupTasks) {
          groupProgress[task.name] = TaskProgress(
            taskName: task.name,
            isCompleted: false,
          );
        }

        final defaultStudent = StudentProgress(
          id: studentId,
          name: '학생',
          number: 0,
          group: 1,
          individualProgress: individualProgress,
          groupProgress: groupProgress,
        );

        // 캐시 업데이트
        _studentCache[studentId] = defaultStudent;

        return defaultStudent;
      }
    } catch (e) {
      print('학생 데이터 동기화 오류: $e');
      _error = '데이터 동기화 오류: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
// 2. task_provider.dart의 _convertToStudentProgress 메서드 수정

  void _convertToStudentProgress(List<FirebaseStudentModel> studentList) async {
    final progressList = <StudentProgress>[];
    print(
        '변환 시작: 학생 수 ${studentList.length}명, 개인과제 ${_individualTasks.length}개, 단체과제 ${_groupTasks.length}개');

    // 해결책 1: 과제 목록이 비어있으면 강제로 로드
// _convertToStudentProgress 메서드 내에서 과제 목록이 비어있는 경우의 처리
    if (_individualTasks.isEmpty || _groupTasks.isEmpty) {
      print('경고: 과제 목록이 비어 있습니다! 과제 데이터 로드 필요');

      // 하드코딩된 데이터 직접 사용
      _individualTasks = List.from(_hardcodedIndividualTasks);
      _groupTasks = List.from(_hardcodedGroupTasks);

      print(
          '과제 목록 강제 로드 완료: 개인=${_individualTasks.length}, 단체=${_groupTasks.length}개');
    }
    for (var student in studentList) {
      final individualProgress = <String, TaskProgress>{};
      final groupProgress = <String, TaskProgress>{};

      // 해결책 2: 모든 가능한 개인 과제를 포함 (항상 모든 과제를 초기화)
      for (var taskModel in _individualTasks) {
        final taskName = taskModel.name;
        final value = student.individualTasks[taskName];
        final isCompleted = value != null && value['completed'] == true;
        final completedDate =
            value != null ? value['completedDate']?.toString() : null;

        individualProgress[taskName] = TaskProgress(
          taskName: taskName,
          isCompleted: isCompleted,
          completedDate: completedDate,
        );
      }

      // 해결책 3: 모든 가능한 단체 과제를 포함 (항상 모든 과제를 초기화)
      for (var taskModel in _groupTasks) {
        final taskName = taskModel.name;
        final value = student.groupTasks[taskName];
        final isCompleted = value != null && value['completed'] == true;
        final completedDate =
            value != null ? value['completedDate']?.toString() : null;

        groupProgress[taskName] = TaskProgress(
          taskName: taskName,
          isCompleted: isCompleted,
          completedDate: completedDate,
        );
      }

      // StudentProgress 객체 생성
      int studentNumber = 0;
      try {
        // 학번 끝 두자리를 번호로 사용
        if (student.studentId.length >= 2) {
          studentNumber = int.tryParse(
                  student.studentId.substring(student.studentId.length - 2)) ??
              0;
        }
      } catch (e) {
        print('학번 파싱 오류: ${student.studentId} - $e');
      }

      progressList.add(StudentProgress(
        id: student.id,
        name: student.name,
        number: studentNumber,
        group: student.group,
        individualProgress: individualProgress,
        groupProgress: groupProgress,
        attendance: student.attendance,
      ));
    }

    _students = progressList;
    _calculateStampCount();
    _calculateGroupStampCounts(); // 모둠별 도장 개수 계산
    print('변환 완료: StudentProgress ${_students.length}명');
  }

  // 도장 개수 계산
  void _calculateStampCount() {
    int count = 0;
    for (var student in _students) {
      // 개인 과제 성공 개수
      count +=
          student.individualProgress.values.where((p) => p.isCompleted).length;
      // 단체 과제 성공 개수
      count += student.groupProgress.values.where((p) => p.isCompleted).length;
    }

    _stampCount = count;
  }

// 3. task_provider.dart의 updateTaskStatus 메서드 수정

// task_provider.dart 파일의 updateTaskStatus 메서드 수정

  Future<void> updateTaskStatus(String studentId, String taskName,
      bool isCompleted, bool isGroupTask) async {
    _error = '';
    _isLoading = true;
    notifyListeners();

    try {
      // 실행 시간 제한 설정
      const timeout = Duration(seconds: 2);

      // 서비스를 통해 Firebase 업데이트 수행 (타임아웃 설정)
      await _taskService
          .updateTaskStatus(studentId, taskName, isCompleted, isGroupTask)
          .timeout(timeout, onTimeout: () {
        // 타임아웃 발생 시 로컬만 업데이트하고 완료 처리
        print('Firebase 업데이트 타임아웃 - 로컬만 업데이트');
        _error = '서버 응답 지연 - 로컬에 저장됨';
        return;
      });

      // 로컬 상태 업데이트
      _updateLocalTaskStatus(studentId, taskName, isCompleted, isGroupTask);
    } catch (e) {
      print('과제 상태 업데이트 오류: $e');
      _error = '데이터 저장 오류: $e';
      _isOffline = true;

      // 네트워크 오류더라도 로컬 상태는 업데이트
      _updateLocalTaskStatus(studentId, taskName, isCompleted, isGroupTask);

      _error = '네트워크 연결 오류. 변경 사항은 로컬에 저장되었으며 연결이 복구되면 자동으로 동기화됩니다.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

// task_provider.dart 파일의 _updateLocalTaskStatus 메서드에서 날짜 생성 부분 수정

  void _updateLocalTaskStatus(
      String studentId, String taskName, bool isCompleted, bool isGroupTask) {
    final studentIndex = _students.indexWhere((s) => s.id == studentId);
    if (studentIndex == -1) {
      print('학생을 찾을 수 없음: $studentId');
      return;
    }

    final student = _students[studentIndex];

    // 과제 맵 처리 (개인 또는 단체)
    final Map<String, TaskProgress> currentProgress = isGroupTask
        ? Map<String, TaskProgress>.from(student.groupProgress)
        : Map<String, TaskProgress>.from(student.individualProgress);

    // 기존 과제 상태를 확인하고 업데이트
    final existing = currentProgress[taskName];

    // 새로운 완료 날짜 생성
    String? newCompletedDate;

    if (isCompleted) {
      if (existing?.isCompleted == true && existing?.completedDate != null) {
        // 이미 완료된 상태면 기존 날짜 유지
        newCompletedDate = existing?.completedDate;
      } else {
        // 새로 완료하는 경우 현재 날짜 설정 (yyyy-MM-dd 형식으로 저장)
        final now = DateTime.now();
        newCompletedDate = now.toIso8601String();
      }
    } else {
      // 완료 취소하는 경우 날짜 null로 설정
      newCompletedDate = null;
    }

    // TaskProgress 객체 업데이트
    currentProgress[taskName] = TaskProgress(
      taskName: taskName,
      isCompleted: isCompleted,
      completedDate: newCompletedDate,
    );

    // 학생 객체 업데이트
    final updatedStudent = student.copyWith(
      individualProgress:
          isGroupTask ? student.individualProgress : currentProgress,
      groupProgress: isGroupTask ? currentProgress : student.groupProgress,
    );

    // 학생 목록 업데이트
    final newStudents = List<StudentProgress>.from(_students);
    newStudents[studentIndex] = updatedStudent;

    _students = newStudents;
    _calculateStampCount();
    _calculateGroupStampCounts(); // 모둠별 도장 개수 계산

    print(
        '로컬 과제 상태 업데이트 완료: $studentId, $taskName, $isCompleted (${isGroupTask ? '단체' : '개인'})');
  }

  // 모둠별 도장 개수 계산
  void _calculateGroupStampCounts() {
    // 모둠별 도장 개수 초기화
    _groupStampCounts.clear();

    // 학생들을 순회하며 모둠별 도장 개수 계산
    for (var student in _students) {
      // 학생의 모둠 번호
      int groupNum = student.group;

      // 개인 과제 완료 개수
      int individualCompleted =
          student.individualProgress.values.where((p) => p.isCompleted).length;

      // 단체 과제 완료 개수
      int groupCompleted =
          student.groupProgress.values.where((p) => p.isCompleted).length;

      // 모둠별 도장 개수 누적
      _groupStampCounts[groupNum] = (_groupStampCounts[groupNum] ?? 0) +
          individualCompleted +
          groupCompleted;
    }
  }

  // 모둠별 도장 개수 가져오기
  int getGroupStampCount(int groupNum) {
    return _groupStampCounts[groupNum] ?? 0;
  }

// 변경 후
  bool canStartGroupActivities(int groupId) {
    // 유효한 그룹 ID 확인
    if (groupId <= 0) {
      print('잘못된 그룹 ID: $groupId');
      return false;
    }

    // 같은 그룹의 모든 학생 찾기 (학생이 없으면 현재 로그인한 학생이라도 포함)
    List<StudentProgress> groupStudents =
        _students.where((s) => s.group == groupId).toList();

    // 학생이 없는 경우 캐시에서 검색
    if (groupStudents.isEmpty) {
      print('그룹 $groupId에 학생이 없어 캐시에서 검색합니다');

      // 캐시에서 해당 그룹의 학생 찾기
      _studentCache.forEach((id, student) {
        if (student.group == groupId &&
            !groupStudents.any((s) => s.id == student.id)) {
          groupStudents.add(student);
        }
      });
    }

    // 여전히 학생이 없는 경우
    if (groupStudents.isEmpty) {
      print('그룹 $groupId에 학생을 찾을 수 없습니다');
      return false;
    }

    // 그룹의 모든 학생의 개인줄넘기 성공 수 합계
    int totalSuccesses = 0;
    for (var student in groupStudents) {
      totalSuccesses +=
          student.individualProgress.values.where((p) => p.isCompleted).length;
    }

    // 필요한 성공 개수: 학생 수 × 5
    int neededSuccesses = groupStudents.length * 5;

    print(
        '단체줄넘기 자격 확인 - 그룹 $groupId: 학생 ${groupStudents.length}명, 성공 $totalSuccesses개, 필요 $neededSuccesses개');

    return totalSuccesses >= neededSuccesses;
  }

  // task_provider.dart 파일에 다음 메서드 추가

// task_provider.dart에 추가할 메서드 수정

// 특정 학생 데이터 새로고침 (개선된 버전)
  Future<void> refreshStudentData(String studentId) async {
    if (studentId.isEmpty) return;

    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      print('학생 데이터 새로고침 시도: $studentId');

      // 서버에서 학생 데이터 새로 가져오기
      final studentData = await _taskService.getStudentDataDirectly(studentId);

      if (studentData != null) {
        // 개인 과제 완료 상태 확인 및 로깅
        int completedTaskCount = 0;
        studentData.individualTasks.forEach((key, value) {
          if (value is Map && value['completed'] == true) {
            completedTaskCount++;
            print('완료된 과제 확인: $key');
          }
        });
        print('서버에서 확인된 완료 과제 수: $completedTaskCount');

        // 학생 진행 상태 변환
        final individualProgress = <String, TaskProgress>{};
        final groupProgress = <String, TaskProgress>{};

        // 개인 과제 처리
        for (var task in _individualTasks) {
          final value = studentData.individualTasks[task.name];
          final isCompleted = value is Map && value['completed'] == true;
          final completedDate =
              value is Map ? value['completedDate']?.toString() : null;

          individualProgress[task.name] = TaskProgress(
            taskName: task.name,
            isCompleted: isCompleted,
            completedDate: completedDate,
          );

          print('과제 상태 설정: ${task.name}, 완료: $isCompleted, 날짜: $completedDate');
        }

        // 단체 과제 처리
        for (var task in _groupTasks) {
          final value = studentData.groupTasks[task.name];
          final isCompleted = value is Map && value['completed'] == true;
          final completedDate =
              value is Map ? value['completedDate']?.toString() : null;

          groupProgress[task.name] = TaskProgress(
            taskName: task.name,
            isCompleted: isCompleted,
            completedDate: completedDate,
          );
        }

        // 중요: 학생 ID 일관되게 사용
        final studentIdToUse = studentData.id;

        // 학생 목록에서 중복 제거 (ID 또는 studentId 기준)
        _students = _students
            .where(
                (s) => s.id != studentIdToUse && s.id != studentData.studentId)
            .toList();

        // 학생 진도 정보 생성
        final updatedStudent = StudentProgress(
          id: studentIdToUse,
          name: studentData.name,
          number: int.tryParse(studentData.studentId.substring(
                  studentData.studentId.length > 2
                      ? studentData.studentId.length - 2
                      : 0)) ??
              0,
          group: studentData.group,
          individualProgress: individualProgress,
          groupProgress: groupProgress,
          attendance: studentData.attendance,
        );

        // 학생 목록에 추가
        _students = [..._students, updatedStudent];

        // 디버깅 정보 출력
        print('학생 데이터 새로고침 성공: $studentId');
        print(
            '개인 과제 완료: ${individualProgress.values.where((p) => p.isCompleted).length}개');
        print(
            '단체 과제 완료: ${groupProgress.values.where((p) => p.isCompleted).length}개');

        // 도장 개수 재계산
        _calculateStampCount();
        _calculateGroupStampCounts();
      }
    } catch (e) {
      print('학생 데이터 새로고침 오류: $e');
      _error = '데이터 새로고침 오류: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 수동 데이터 동기화 (사용자가 동기화 버튼을 누를 때 호출)
  Future<void> syncData() async {
    if (await _taskService.isNetworkAvailable()) {
      _isLoading = true;
      _error = '';
      notifyListeners();

      try {
        // 오프라인에서 변경된 내용이 있으면 동기화
        await _taskService.syncOfflineChanges();

        // 최신 데이터로 다시 로드
        _refreshData();

        _isOffline = false;
        _error = '';
      } catch (e) {
        _error = '동기화 오류: $e';
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    } else {
      _error = '네트워크 연결을 확인해주세요.';
      notifyListeners();
    }
  }
}
