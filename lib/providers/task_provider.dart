// lib/providers/task_provider.dart
import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/ui_models.dart';
import '../services/task_service.dart';
import '../models/firebase_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../utils/constants.dart';

/// 학생 과제 데이터 및 상태를 관리하는 Provider
class TaskProvider extends ChangeNotifier {
  final TaskService _taskService = TaskService();

  // 상태 관리 변수들
  List<StudentProgress> _students = [];
  List<TaskModel> _individualTasks = [];
  List<TaskModel> _groupTasks = [];
  int _currentLevel = 1;
  int _currentWeek = 1;
  int _stampCount = 0;
  String _selectedClass = '';
  bool _isLoading = false;
  bool _isOffline = false;
  bool _disposed = false;
  String _error = '';

  // 구독 관리를 위한 변수
  StreamSubscription? _classSubscription;
  Timer? _networkCheckTimer;

  // Getters
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

  // 생성자
  TaskProvider() {
    _initialize();
  }

  /// 초기화 메서드
  Future<void> _initialize() async {
    await _loadTasks();
    await _loadSavedSettings();
    _setupNetworkListener();
  }

  /// 네트워크 상태 모니터링 설정
  void _setupNetworkListener() {
    // 초기 상태 확인
    _checkNetworkStatus();

    // 주기적으로 네트워크 상태 확인 (30초마다)
    _networkCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_disposed) {
        _checkNetworkStatus();
      }
    });
  }

  /// 현재 네트워크 상태 확인
  Future<void> _checkNetworkStatus() async {
    final previousState = _isOffline;
    _isOffline = !(await _taskService.isNetworkAvailable());

    // 오프라인에서 온라인으로 상태가 변경된 경우 자동 동기화
    if (previousState && !_isOffline) {
      print('네트워크 연결이 복구되었습니다. 데이터 동기화 중...');
      _autoSyncData();
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _classSubscription?.cancel();
    _networkCheckTimer?.cancel();
    super.dispose();
  }

  /// 저장된 설정 로드
  Future<void> _loadSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentLevel = prefs.getInt(StorageKeys.currentLevel) ?? 1;
      _currentWeek = prefs.getInt(StorageKeys.currentWeek) ?? 1;
      _selectedClass = prefs.getString(StorageKeys.selectedClass) ?? '';

      // 선택된 학급이 있으면 학생 데이터 로드
      if (_selectedClass.isNotEmpty) {
        selectClass(_selectedClass);
      }

      notifyListeners();
    } catch (e) {
      print('설정 로드 오류: $e');
    }
  }

  /// 과제 목록 로드
  Future<void> _loadTasks() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 과제 모델 데이터 사용
      _individualTasks = individualTasks;
      _groupTasks = groupTasks;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _handleError('과제 목록 로드 오류', e);
    }
  }

  /// 학급 선택 및 데이터 구독
  void selectClass(String className) async {
    // 기존 구독 취소
    _classSubscription?.cancel();

    _selectedClass = className;
    _isLoading = true;
    notifyListeners();

    // 설정 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.selectedClass, className);

    try {
      // 학급 데이터를 실시간으로 구독
      _classSubscription =
          _taskService.getClassTasksStream(className).listen((studentList) {
        // 데이터 변환 및 UI 업데이트
        _convertToStudentProgress(studentList);
        _isLoading = false;
        notifyListeners();
      }, onError: (error) {
        _handleError('학급 데이터 구독 오류', error);
      });
    } catch (e) {
      _handleError('학급 데이터 구독 예외', e);
    }
  }

  /// FirebaseStudentModel을 StudentProgress로 변환
  void _convertToStudentProgress(List<FirebaseStudentModel> studentList) {
    final progressList = <StudentProgress>[];

    for (var student in studentList) {
      final individualProgress =
          _createTaskProgressMap(student.individualTasks, _individualTasks);
      final groupProgress =
          _createTaskProgressMap(student.groupTasks, _groupTasks);

      // StudentProgress 객체 생성
      int studentNumber = _extractStudentNumber(student.studentId);

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
  }

  /// 학번에서 번호 추출
  int _extractStudentNumber(String studentId) {
    try {
      // 학번 끝 두자리를 번호로 사용
      if (studentId.length >= 2) {
        return int.tryParse(studentId.substring(studentId.length - 2)) ?? 0;
      }
    } catch (e) {
      print('학번 파싱 오류: $studentId - $e');
    }
    return 0;
  }

  /// 과제 진행 상황 맵 생성
  Map<String, TaskProgress> _createTaskProgressMap(
      Map<String, dynamic> sourceMap, List<TaskModel> taskModels) {
    final result = <String, TaskProgress>{};

    // 모든 가능한 과제 먼저 추가 (미완료 상태로)
    for (var taskModel in taskModels) {
      final taskName = taskModel.name;
      final value = sourceMap[taskName];
      final isCompleted = value != null && value['completed'] == true;
      final completedDate =
          value != null ? value['completedDate']?.toString() : null;

      result[taskName] = TaskProgress(
        taskName: taskName,
        isCompleted: isCompleted,
        completedDate: completedDate,
      );
    }

    return result;
  }

  /// 도장 개수 계산
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

  /// 현재 레벨 설정
  void setCurrentLevel(int level) async {
    _currentLevel = level;

    // 설정 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.currentLevel, level);

    notifyListeners();
  }

  /// 현재 주차 설정
  void setCurrentWeek(int week) async {
    _currentWeek = week;

    // 설정 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.currentWeek, week);

    notifyListeners();
  }

  /// 단체줄넘기 시작 가능 여부 확인
  bool canStartGroupActivities(int groupId) {
    // 같은 그룹의 모든 학생 찾기
    final groupStudents = _students.where((s) => s.group == groupId).toList();

    if (groupStudents.isEmpty) {
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

    return totalSuccesses >= neededSuccesses;
  }

  /// 과제 상태 업데이트
  Future<void> updateTaskStatus(String studentId, String taskName,
      bool isCompleted, bool isGroupTask) async {
    _error = '';

    try {
      // UI 즉시 업데이트 (낙관적 업데이트)
      _updateLocalTaskStatus(studentId, taskName, isCompleted, isGroupTask);

      // Firebase에 변경 사항 저장
      await _taskService.updateTaskStatus(
          studentId, taskName, isCompleted, isGroupTask);
    } catch (e) {
      // 오프라인 모드 전환
      _isOffline = true;
      _error = AppStrings.offlineMode;
      notifyListeners();
    }
  }

  /// 로컬 과제 상태 업데이트
  void _updateLocalTaskStatus(
      String studentId, String taskName, bool isCompleted, bool isGroupTask) {
    // 현재 학생 찾기
    final studentIndex = _students.indexWhere((s) => s.id == studentId);
    if (studentIndex == -1) return;

    final student = _students[studentIndex];

    // 새로운 진행 상황 맵 생성
    final Map<String, TaskProgress> updatedProgress = isGroupTask
        ? Map.from(student.groupProgress)
        : Map.from(student.individualProgress);

    // 작업 업데이트
    updatedProgress[taskName] = TaskProgress(
      taskName: taskName,
      isCompleted: isCompleted,
      completedDate: isCompleted ? DateTime.now().toString() : null,
    );

    // 학생 정보 업데이트
    final updatedStudent = student.copyWith(
      individualProgress:
          isGroupTask ? student.individualProgress : updatedProgress,
      groupProgress: isGroupTask ? updatedProgress : student.groupProgress,
    );

    // 학생 목록 업데이트
    final newStudents = List<StudentProgress>.from(_students);
    newStudents[studentIndex] = updatedStudent;

    _students = newStudents;
    _calculateStampCount();

    notifyListeners();
  }

  /// 자동 동기화 실행
  Future<void> _autoSyncData() async {
    if (_isOffline) return;

    try {
      await _taskService.syncOfflineChanges();
      _reloadData();
    } catch (e) {
      _error = '자동 동기화 실패: $e';
      notifyListeners();
    }
  }

  /// 데이터 조용히 다시 로드 (UI 로딩 표시 없이)
  Future<void> _reloadData() async {
    if (_selectedClass.isEmpty) return;

    try {
      _classSubscription?.cancel();
      _classSubscription = _taskService
          .getClassTasksStream(_selectedClass)
          .listen((studentList) {
        _convertToStudentProgress(studentList);
        notifyListeners();
      }, onError: (error) {
        print('데이터 리로드 중 오류: $error');
      });
    } catch (e) {
      print('데이터 리로드 중 오류: $e');
    }
  }

  /// 수동 데이터 동기화 (사용자가 동기화 버튼을 누를 때 호출)
  Future<void> syncData() async {
    if (await _taskService.isNetworkAvailable()) {
      _isLoading = true;
      _error = '';
      notifyListeners();

      try {
        await _taskService.syncOfflineChanges();
        selectClass(_selectedClass);
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

  /// 오류 처리 통합 메서드
  void _handleError(String context, dynamic error) {
    print('$context: $error');
    _isLoading = false;
    _error = error.toString();
    _isOffline = true;
    notifyListeners();
  }
}
