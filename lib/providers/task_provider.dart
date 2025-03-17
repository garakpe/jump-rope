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

  // 상태 변수
  List<StudentProgress> _students = [];
  List<TaskModel> _individualTasks = [];
  List<TaskModel> _groupTasks = [];
  int _currentLevel = 1;
  int _currentWeek = 1;
  int _stampCount = 0;
  String _selectedClass = '';
  bool _isLoading = false;
  bool _isOffline = false;
  bool _previousOfflineState = false;
  bool _disposed = false;
  String _error = '';
  final Map<String, StudentProgress> _studentCache = {};
  final Map<String, int> _groupStampCounts = {}; // 타입을 Map<String, int>로 변경
  StreamSubscription? _classSubscription;

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

  // 초기화 함수
  Future<void> _initialize() async {
    await _loadTasks();
    await _loadSavedSettings();
    _checkNetworkStatus();
  }

  @override
  void dispose() {
    _disposed = true;
    _classSubscription?.cancel();
    super.dispose();
  }

  // 학생 캐시에서 조회
  StudentProgress? getStudentFromCache(String studentId) {
    return _studentCache[studentId];
  }

  // 두 학생이 같은 학급인지 확인
  bool isInSameClass(StudentProgress student1, StudentProgress student2) {
    // 1. 같은 학생이면 당연히 같은 반
    if (student1.id == student2.id) return true;

    // 2. 학번 체계 기반 비교 (학번 앞 3자리로 비교)
    if (student1.studentId.length >= 5 && student2.studentId.length >= 5) {
      try {
        final classInfo1 = student1.studentId.substring(0, 3);
        final classInfo2 = student2.studentId.substring(0, 3);
        return classInfo1 == classInfo2;
      } catch (e) {
        print('학번 비교 실패: ${student1.studentId} vs ${student2.studentId} - $e');
      }
    }

    // 학번으로 비교할 수 없는 경우
    return false;
  }

  // ============ 네트워크 및 동기화 관련 메서드 ============

  // 주기적 네트워크 상태 확인
  void _checkNetworkStatus() async {
    if (_disposed) return;

    final wasOfflineBefore = _isOffline;
    _isOffline = !(await _taskService.isNetworkAvailable());

    // 오프라인에서 온라인으로 상태가 변경된 경우 자동 동기화
    if (wasOfflineBefore && !_isOffline) {
      await _autoSyncData();
    }

    _previousOfflineState = _isOffline;
    notifyListeners();

    // 주기적으로 상태 확인 (30초마다)
    if (!_disposed) {
      Future.delayed(const Duration(seconds: 30), _checkNetworkStatus);
    }
  }

  // 자동 데이터 동기화
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
        _setError('자동 동기화 오류: $e');
      }
    }
  }

  // 수동 데이터 동기화
  Future<void> syncData() async {
    if (await _taskService.isNetworkAvailable()) {
      _setLoading(true);

      try {
        // 오프라인에서 변경된 내용 동기화
        await _taskService.syncOfflineChanges();

        // 최신 데이터로 다시 로드
        _refreshData();

        _isOffline = false;
        _setError('');
      } catch (e) {
        _setError('동기화 오류: $e');
      } finally {
        _setLoading(false);
      }
    } else {
      _setError('네트워크 연결을 확인해주세요.');
    }
  }

  // 데이터 새로고침
  Future<void> _refreshData() async {
    if (_selectedClass.isEmpty) return;

    // 기존 구독 취소 후 다시 데이터 로드
    _classSubscription?.cancel();
    selectClass(_selectedClass);
  }

  // ============ 사용자 변경 및 설정 관련 메서드 ============

  // 사용자 변경 처리 메서드 수정
  void handleUserChanged(String? newStudentId, String? groupId) {
    // 데이터 초기화
    _students = [];
    _studentCache.clear();
    _setError('');
    _setLoading(false);

    // 새 사용자 ID가 있을 경우 데이터 로드
    if (newStudentId != null && newStudentId.isNotEmpty) {
      // 1. 학생 자신의 데이터 로드
      syncStudentDataFromServer(newStudentId);

      // 2. 학생의 모둠원 데이터 로드 (그룹 ID가 있는 경우)
      if (groupId != null && groupId.isNotEmpty && groupId != '0') {
        loadGroupMembers(groupId, '1'); // 1학년으로 가정 (필요시 동적으로 변경)
      }
    }

    notifyListeners();
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
      }

      notifyListeners();
    } catch (e) {
      print('설정 로드 오류: $e');
      _setError('설정 로드 오류: $e');
    }
  }

  // 현재 레벨 설정
  void setCurrentLevel(int level) async {
    _currentLevel = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentLevel', level);
    notifyListeners();
  }

  // 현재 주차 설정
  void setCurrentWeek(int week) async {
    _currentWeek = week;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentWeek', week);
    notifyListeners();
  }

  // ============ 학급 및 학생 데이터 관련 메서드 ============

  // 학급 선택 및 데이터 로드
  void selectClass(String grade) async {
    // 기존 구독 취소
    _classSubscription?.cancel();

    _selectedClass = grade;
    _setLoading(true);

    // 설정 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedClass', grade);

    try {
      // 학급 데이터를 실시간으로 구독
      _classSubscription =
          _taskService.getClassTasksStream(grade).listen((studentList) {
        // 데이터 변환 및 UI 업데이트
        _convertToStudentProgress(studentList);
        _setLoading(false);
      }, onError: (error) {
        _setError('Firebase에서 학급 데이터를 가져오는 중 오류가 발생했습니다: $error');
        _isOffline = true;
        _setLoading(false);
      });
    } catch (e) {
      _setError('데이터 연결 오류: $e');
      _isOffline = true;
      _setLoading(false);
    }
  }

  // 과제 데이터 로드
  Future<void> _loadTasks() async {
    _setLoading(true);

    try {
      _individualTasks = TaskModel.getIndividualTasks();
      _groupTasks = TaskModel.getGroupTasks();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // 모둠원 데이터 로드
  Future<bool> loadGroupMembers(String groupId, String grade) async {
    if (groupId.isEmpty || grade.isEmpty) return false;

    _setLoading(true);

    try {
      // 서비스를 통해 모둠원 불러오기
      final groupMembers = await _taskService.getGroupMembers(groupId, grade);

      if (groupMembers.isEmpty) {
        _setLoading(false);
        return false;
      }

      // 각 모둠원을 StudentProgress로 변환
      for (var memberData in groupMembers) {
        final individualProgress = _convertTasksToProgress(
            memberData.individualTasks, _individualTasks);
        final groupProgress =
            _convertTasksToProgress(memberData.groupTasks, _groupTasks);

        // 학번 유효성 검사
        String studentId = memberData.studentId;
        if (studentId.isEmpty) {
          // 임시 학번 생성
          studentId = '${grade}01${memberData.id.substring(0, 2)}';
        }

        // 학생 진도 정보 생성
        final memberProgress = _createStudentProgress(
            memberData, individualProgress, groupProgress, studentId);

        // 캐시 및 상태 업데이트
        _studentCache[memberData.id] = memberProgress;
        _updateStudentInList(memberProgress);
      }

      // 도장 개수 재계산
      _calculateStampCount();
      _calculateGroupStampCounts();

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('모둠원 데이터 로드 오류: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<StudentProgress?> syncStudentDataFromServer(String studentId) async {
    if (studentId.isEmpty) return null;

    // 이미 로딩 중이면 중복 작업 방지
    if (_isLoading) {
      return _studentCache[studentId];
    }

    _setLoading(true);
    _setError('');

    try {
      // 서버에서 학생 데이터 가져오기
      FirebaseStudentModel? studentData;
      try {
        studentData = await _taskService
            .getStudentDataDirectly(studentId)
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        // Firebase에서 실패했지만 캐시된 데이터가 있는 경우
        final cachedStudent = _studentCache[studentId];
        if (cachedStudent != null) {
          _setError('서버 연결 문제로 로컬 데이터를 사용합니다');
          _setLoading(false);
          return cachedStudent;
        }

        // 캐시도 없는 경우 에러 표시
        _setError('학생 데이터를 가져올 수 없습니다: $e');
        _setLoading(false);
        return null;
      }

      if (studentData != null) {
        // 진행 상태 데이터 변환
        final individualProgress = _convertTasksToProgress(
            studentData.individualTasks, _individualTasks);

        final groupProgress =
            _convertTasksToProgress(studentData.groupTasks, _groupTasks);

        // 학생 진행 정보 생성
        final student = _createStudentProgress(studentData, individualProgress,
            groupProgress, studentData.studentId);

        // 캐시 및 상태 업데이트
        _studentCache[studentId] = student;
        setStudentProgress(student);

        // 모둠원 정보 로드
        final groupId = studentData.group;
        if (groupId.isNotEmpty && groupId != '0') {
          // 학급 정보 결정 (classNum 우선, 없으면 grade)
          final classInfo = studentData.classNum.isNotEmpty
              ? studentData.classNum
              : studentData.grade;

          // 모둠원 로드
          loadGroupMembers(groupId, classInfo);
        }

        _setLoading(false);
        return student;
      } else {
        // 데이터를 가져오지 못한 경우
        _setError('학생 정보를 찾을 수 없습니다');
        _setLoading(false);
        return null;
      }
    } catch (e) {
      _setError('데이터 동기화 오류: $e');
      _setLoading(false);
      return null;
    }
  }

  // 학생 데이터 업데이트
  void setStudentProgress(StudentProgress student) {
    if (student.id.isEmpty) return;

    // 학생 목록 업데이트
    _updateStudentInList(student);

    // 캐시 업데이트
    _studentCache[student.id] = student;

    // 도장 개수 재계산
    _calculateStampCount();
    _calculateGroupStampCounts();

    notifyListeners();
  }

  // 학생 목록에서 학생 업데이트 또는 추가
  void _updateStudentInList(StudentProgress student) {
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
  }

  // 특정 학생 데이터 새로고침
  Future<void> refreshStudentData(String studentId, {int? groupId}) async {
    if (studentId.isEmpty) return;

    _setLoading(true);
    _setError('');

    try {
      // 서버에서 학생 데이터 새로 가져오기
      final studentData = await _taskService.getStudentDataDirectly(studentId);

      if (studentData != null) {
        // 진행 상태 데이터 변환
        final individualProgress = _convertTasksToProgress(
            studentData.individualTasks, _individualTasks);

        final groupProgress =
            _convertTasksToProgress(studentData.groupTasks, _groupTasks);

        // 중요: 학생 ID 일관되게 사용
        final studentIdToUse = studentData.id;

        // 학생 목록에서 중복 제거
        _students = _students
            .where(
                (s) => s.id != studentIdToUse && s.id != studentData.studentId)
            .toList();

        // 학생 진행 정보 생성
        final updatedStudent = _createStudentProgress(studentData,
            individualProgress, groupProgress, studentData.studentId);

        // 학생 목록에 추가 및 캐시 업데이트
        _students = [..._students, updatedStudent];
        _studentCache[studentIdToUse] = updatedStudent;

        // 도장 개수 재계산
        _calculateStampCount();
        _calculateGroupStampCounts();

        // 모둠원 데이터도 함께 로드
        final studentGroup = studentData.group;
        if (studentGroup.isNotEmpty) {
          // 모둠원 로드
          await loadGroupMembers(studentGroup, '1');
        }
      }
    } catch (e) {
      _setError('데이터 새로고침 오류: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ============ 과제 관련 메서드 ============

  // 과제 상태 업데이트
  Future<void> updateTaskStatus(String studentId, String taskName,
      bool isCompleted, bool isGroupTask) async {
    _setError('');
    _setLoading(true);

    try {
      // 서비스를 통해 Firebase 업데이트 수행 (타임아웃 설정)
      await _taskService
          .updateTaskStatus(studentId, taskName, isCompleted, isGroupTask)
          .timeout(const Duration(seconds: 2), onTimeout: () {
        _setError('서버 응답 지연 - 로컬에 저장됨');
        return;
      });

      // 로컬 상태 업데이트
      _updateLocalTaskStatus(studentId, taskName, isCompleted, isGroupTask);
    } catch (e) {
      _setError('네트워크 연결 오류. 변경 사항은 로컬에 저장되었으며 연결이 복구되면 자동으로 동기화됩니다.');
      _isOffline = true;

      // 네트워크 오류더라도 로컬 상태는 업데이트
      _updateLocalTaskStatus(studentId, taskName, isCompleted, isGroupTask);
    } finally {
      _setLoading(false);
    }
  }

  // 로컬 과제 상태 업데이트
  void _updateLocalTaskStatus(
      String studentId, String taskName, bool isCompleted, bool isGroupTask) {
    final studentIndex = _students.indexWhere((s) => s.id == studentId);
    if (studentIndex == -1) return;

    final student = _students[studentIndex];

    // 과제 맵 처리 (개인 또는 단체) - null일 경우 빈 맵으로 초기화
    final Map<String, TaskProgress> currentProgress = isGroupTask
        ? Map<String, TaskProgress>.from(student.groupProgress ?? {})
        : Map<String, TaskProgress>.from(student.individualProgress ?? {});

    // 기존 과제 상태 확인
    final existing = currentProgress[taskName];

    // 완료 날짜 결정
    String? newCompletedDate;
    if (isCompleted) {
      if (existing?.isCompleted == true && existing?.completedDate != null) {
        // 이미 완료된 상태면 기존 날짜 유지
        newCompletedDate = existing!.completedDate;
      } else {
        // 새로 완료하는 경우 현재 날짜 설정
        newCompletedDate = DateTime.now().toIso8601String();
      }
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

    // 캐시도 업데이트
    _studentCache[studentId] = updatedStudent;

    // 도장 개수 재계산
    _calculateStampCount();
    _calculateGroupStampCounts();

    notifyListeners();
  }

  // 단체줄넘기 시작 가능 여부 확인 (리팩토링)
  bool canStartGroupActivities(String groupId) {
    if (groupId.isEmpty) return false;

    // 직접 특정 그룹의 도장 개수 확인
    final groupStamps = _groupStampCounts[groupId] ?? 0;

    // 그룹에 속한 학생 수 계산
    int studentCount = 0;
    for (var student in _students) {
      if (student.group == groupId) {
        studentCount++;
      }
    }

    // 캐시에서도 확인
    if (studentCount == 0) {
      for (var student in _studentCache.values) {
        if (student.group == groupId) {
          studentCount++;
        }
      }
    }

    // 학생 수가 없으면 그룹 활동 불가
    if (studentCount == 0) return false;

    // 필요한 도장 수: 학생 수 × 5
    int requiredStamps = studentCount * 5;

    return groupStamps >= requiredStamps;
  }

  // 모둠별 도장 개수 가져오기
  int getGroupStampCount(String groupId) {
    return _groupStampCounts[groupId] ?? 0;
  }

  // ============ 데이터 변환 및 계산 메서드 ============

  // Firebase 과제 데이터를 TaskProgress 객체로 변환
  Map<String, TaskProgress> _convertTasksToProgress(
      Map<String, dynamic>? tasks, List<TaskModel> taskModels) {
    final progress = <String, TaskProgress>{};
    final tasksMap = tasks ?? {};

    for (var task in taskModels) {
      final value = tasksMap[task.name];
      final isCompleted = value is Map && value['completed'] == true;
      final completedDate =
          value is Map ? value['completedDate']?.toString() : null;

      progress[task.name] = TaskProgress(
        taskName: task.name,
        isCompleted: isCompleted,
        completedDate: completedDate,
      );
    }

    return progress;
  }

  // StudentProgress 객체 생성
  StudentProgress _createStudentProgress(
      FirebaseStudentModel data,
      Map<String, TaskProgress> individualProgress,
      Map<String, TaskProgress> groupProgress,
      String studentId) {
    int studentNumber = 0;
    if (studentId.length >= 2) {
      studentNumber =
          int.tryParse(studentId.substring(studentId.length - 2)) ?? 0;
    }

    return StudentProgress(
      id: data.id,
      name: data.name,
      number: studentNumber,
      group: data.group,
      individualProgress: individualProgress,
      groupProgress: groupProgress,
      attendance: data.attendance,
      studentId: studentId,
    );
  }

  // FirebaseStudentModel 목록을 StudentProgress 목록으로 변환
  void _convertToStudentProgress(List<FirebaseStudentModel> studentList) {
    final progressList = <StudentProgress>[];

    // 과제 목록이 비어있으면 강제로 로드
    if (_individualTasks.isEmpty || _groupTasks.isEmpty) {
      _individualTasks = TaskModel.getIndividualTasks();
      _groupTasks = TaskModel.getGroupTasks();
    }

    for (var student in studentList) {
      // 진행 상태 데이터 변환
      final individualProgress =
          _convertTasksToProgress(student.individualTasks, _individualTasks);

      final groupProgress =
          _convertTasksToProgress(student.groupTasks, _groupTasks);

      // 학생 진행 정보 생성
      final studentProgress = _createStudentProgress(
          student, individualProgress, groupProgress, student.studentId);

      progressList.add(studentProgress);
    }

    _students = progressList;
    _calculateStampCount();
    _calculateGroupStampCounts();
  }

  // 전체 도장 개수 계산 (간소화)
  void _calculateStampCount() {
    _stampCount = 0;
    for (var student in _students) {
      // 개인 과제 성공 개수
      _stampCount +=
          student.individualProgress.values.where((p) => p.isCompleted).length;
      // 단체 과제 성공 개수
      _stampCount +=
          student.groupProgress.values.where((p) => p.isCompleted).length;
    }
  }

  // 모둠별 도장 개수 계산 (간소화)
  void _calculateGroupStampCounts() {
    // 기존 카운트 초기화
    _groupStampCounts.clear();

    // 각 학생별로 완료한 과제 수를 모둠별로 집계
    for (var student in _students) {
      String groupId = student.group;
      if (groupId.isEmpty) continue;

      // 개인 과제 성공 개수
      int individualCount =
          student.individualProgress.values.where((p) => p.isCompleted).length;

      // 단체 과제 성공 개수
      int groupCount =
          student.groupProgress.values.where((p) => p.isCompleted).length;

      // 해당 모둠의 기존 카운트에 추가
      _groupStampCounts[groupId] =
          (_groupStampCounts[groupId] ?? 0) + individualCount + groupCount;
    }
  }

  // ============ 유틸리티 메서드 ============

  // 로딩 상태 설정
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // 에러 메시지 설정
  void _setError(String errorMessage) {
    _error = errorMessage;
    notifyListeners();
  }

  // 데이터 로드 오류 처리
  void _handleDataLoadError(String errorMessage) {
    _students = [];
    _error = errorMessage;
    _isOffline = true;
    _isLoading = false;
    notifyListeners();
  }

  // 원본 Firebase 학생 데이터 가져오기
  FirebaseStudentModel? getOriginalStudentData(String studentId) {
    try {
      return _taskService.getCachedStudentData(studentId);
    } catch (e) {
      print('원본 학생 데이터 조회 오류: $e');
      return null;
    }
  }
}
