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

  // 샘플 학생 데이터 로드
  void _loadSampleStudents() {
    // 샘플 데이터 - 실제로는 Firebase에서 가져와야 함
    final sampleStudents = [
      StudentProgress(
        id: '101',
        name: '김철수',
        number: 1,
        group: 1,
        individualProgress: {
          '양발모아 뛰기': TaskProgress(
              taskName: '양발모아 뛰기',
              isCompleted: true,
              completedDate: '2023-09-10'),
          '구보로 뛰기': TaskProgress(taskName: '구보로 뛰기', isCompleted: false),
        },
        groupProgress: {},
      ),
      StudentProgress(
        id: '102',
        name: '홍길동',
        number: 2,
        group: 1,
        individualProgress: {
          '양발모아 뛰기': TaskProgress(taskName: '양발모아 뛰기', isCompleted: false),
        },
        groupProgress: {},
      ),
      StudentProgress(
        id: '103',
        name: '이영희',
        number: 3,
        group: 2,
        individualProgress: {
          '양발모아 뛰기': TaskProgress(
              taskName: '양발모아 뛰기',
              isCompleted: true,
              completedDate: '2023-09-11'),
          '구보로 뛰기': TaskProgress(
              taskName: '구보로 뛰기',
              isCompleted: true,
              completedDate: '2023-09-12'),
        },
        groupProgress: {},
      ),
    ];

    _students = sampleStudents;
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

  // 단체줄넘기 시작 가능 여부 확인
  bool canStartGroupActivities(int groupId) {
    // 같은 그룹의 모든 학생 찾기
    final groupStudents = _students.where((s) => s.group == groupId).toList();

    if (groupStudents.isEmpty) {
      print('그룹 $groupId에 학생이 없습니다.');
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
        '단체줄넘기 자격 확인 - 그룹 $groupId: 성공 $totalSuccesses개, 필요 $neededSuccesses개');

    return totalSuccesses >= neededSuccesses;
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
