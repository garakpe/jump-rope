// lib/providers/task_provider.dart
import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/ui_models.dart';
import '../services/task_service.dart';
import '../models/firebase_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

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

  @override
  void dispose() {
    _disposed = true;
    _classSubscription?.cancel();
    super.dispose();
  }

  // 저장된 설정 로드
  Future<void> _loadSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentLevel = prefs.getInt('currentLevel') ?? 1;
      _currentWeek = prefs.getInt('currentWeek') ?? 1;
      _selectedClass = prefs.getString('selectedClass') ?? '1';

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

  // 과제 목록 로드
  Future<void> _loadTasks() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 기존 하드코딩 데이터 사용
      _individualTasks = individualTasks;
      _groupTasks = groupTasks;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
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

  // 도장 카운트 증가
  void incrementStampCount() {
    _stampCount++;
    notifyListeners();
  }

// task_provider.dart 파일 수정
// selectClass 메서드 수정
  void selectClass(String className) async {
    // 기존 구독 취소
    _classSubscription?.cancel();

    _selectedClass = className;
    _isLoading = true;
    notifyListeners();

    // 설정 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedClass', className);

    print('TaskProvider - 선택된 학급: $className'); // 디버깅 로그 추가

    try {
      // 학급 데이터를 실시간으로 구독
      _classSubscription =
          _taskService.getClassTasksStream(className).listen((studentList) {
        // 데이터 변환 및 UI 업데이트
        print('TaskProvider - 학급 데이터 수신: ${studentList.length}명'); // 디버깅 로그 추가
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
      print('학급 데이터 구독 예외: $e'); // 디버깅 로그 수정
      _isLoading = false;
      _error = e.toString();
      _isOffline = true;
      notifyListeners();

      // 오류 발생 시 샘플 데이터 로드
      _loadSampleStudents();
    }
  }

  // FirebaseStudentModel을 StudentProgress로 변환
  void _convertToStudentProgress(List<FirebaseStudentModel> studentList) {
    final progressList = <StudentProgress>[];
    print(
        '변환 시작: 학생 수 ${studentList.length}명, 개인과제 ${_individualTasks.length}개, 단체과제 ${_groupTasks.length}개');

    // 여기서 _individualTasks와 _groupTasks가 비어있는지 확인
    if (_individualTasks.isEmpty || _groupTasks.isEmpty) {
      print('경고: 과제 목록이 비어 있습니다! 과제 데이터 로드 필요');
      _loadTasks(); // 과제 목록 다시 로드 시도
    }
    for (var student in studentList) {
      final individualProgress = <String, TaskProgress>{};
      final groupProgress = <String, TaskProgress>{};

      // 개인 과제 변환 - 모든 가능한 개인 과제를 포함하도록 수정
      for (var taskModel in individualTasks) {
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

      // 단체 과제 변환 - 모든 가능한 단체 과제를 포함하도록 수정
      for (var taskModel in groupTasks) {
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

// lib/providers/task_provider.dart - updateTaskStatus 메서드

// 과제 상태 업데이트
  Future<void> updateTaskStatus(String studentId, String taskName,
      bool isCompleted, bool isGroupTask) async {
    _error = ''; // 오류 메시지 초기화

    try {
      // UI 즉시 업데이트 (낙관적 업데이트)
      _updateLocalTaskStatus(studentId, taskName, isCompleted, isGroupTask);

      print(
          '과제 상태 업데이트 시작: 학생=$studentId, 과제=$taskName, 완료=$isCompleted, 단체=$isGroupTask');

      // Firebase에 변경 사항 저장
      await _taskService.updateTaskStatus(
          studentId, taskName, isCompleted, isGroupTask);

      // 성공적으로 업데이트됨
      print('Firebase에 과제 상태 업데이트 성공');
    } catch (e) {
      _error = '데이터 저장 오류: $e';
      print('과제 상태 업데이트 오류: $e');

      // 오프라인 모드로 전환
      _isOffline = true;

      // 로컬 저장 시도 - UI는 이미 업데이트됨
      _error = '네트워크 연결 오류. 변경 사항은 로컬에 저장되었으며 연결이 복구되면 자동으로 동기화됩니다.';

      notifyListeners();
    }
  }

// task_provider.dart의 _updateLocalTaskStatus 메서드
  void _updateLocalTaskStatus(
      String studentId, String taskName, bool isCompleted, bool isGroupTask) {
    // 현재 학생 찾기
    final studentIndex = _students.indexWhere((s) => s.id == studentId);
    if (studentIndex == -1) {
      print('학생을 찾을 수 없음: $studentId');
      return;
    }

    final student = _students[studentIndex];
    print('학생을 찾음: ${student.name}, 기존 진행 상황 확인 중...');

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

    print('업데이트된 과제 상태: $taskName, 완료=$isCompleted');

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
    _calculateStampCount(); // 도장 개수 다시 계산

    print('로컬 데이터 업데이트 완료, 총 도장 개수: $_stampCount');

    // 매우 중요: UI 업데이트 알림
    notifyListeners();
  }

  // 자동 동기화 실행
  Future<void> _autoSyncData() async {
    if (_isOffline) return; // 아직 오프라인이면 동기화 시도하지 않음

    try {
      // 오프라인에서 변경된 내용이 있으면 동기화
      await _taskService.syncOfflineChanges();

      // 최신 데이터로 다시 로드 (조용히 백그라운드에서 실행)
      _reloadData();

      print('네트워크 재연결 후 데이터 동기화 완료');
    } catch (e) {
      print('자동 동기화 중 오류 발생: $e');
      _error = '자동 동기화 실패: $e';
      notifyListeners();
    }
  }

  // 데이터 조용히 다시 로드 (UI 로딩 표시 없이)
  Future<void> _reloadData() async {
    if (_selectedClass.isEmpty) return;

    try {
      // 구독 취소
      _classSubscription?.cancel();

      // 다시 구독 설정
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
}
