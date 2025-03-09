// lib/providers/reflection_provider.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/reflection_model.dart';
import '../models/firebase_models.dart';
import '../services/reflection_service.dart';

class ReflectionProvider extends ChangeNotifier {
  final ReflectionService _reflectionService = ReflectionService();

  List<ReflectionModel> _reflectionCards = [];
  List<FirebaseReflectionModel> _submissions = [];
  int _selectedReflectionId = 0;
  String _selectedClass = '';
  int _selectedWeek = 1;
  bool _isLoading = false;
  bool _isOffline = false;
  String _error = '';
  String? _downloadUrl;

  // 구독 관리
  StreamSubscription? _reflectionsSubscription;

  // 현재 선택된 반의 주차별 제출 현황
  final Map<String, bool> _submissionStatus = {};

  // 게터
  List<FirebaseReflectionModel> get submissions => _submissions;
  List<ReflectionModel> get reflectionCards => _reflectionCards;
  int get selectedReflectionId => _selectedReflectionId;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  String get error => _error;
  String? get downloadUrl => _downloadUrl;
  Map<String, bool> get submissionStatus => _submissionStatus;
  int get currentWeek => _selectedWeek;

  // 생성자에서 성찰 질문 로드
  ReflectionProvider() {
    _loadReflectionQuestions();
    // 샘플 데이터 생성 (개발용)
    _reflectionService.createSampleReflections();
  }

  @override
  void dispose() {
    _reflectionsSubscription?.cancel();
    super.dispose();
  }

  // 네트워크 상태 확인
  Future<void> checkNetworkStatus() async {
    final wasOffline = _isOffline;
    _isOffline = !(await _reflectionService.isNetworkAvailable());

    // 오프라인에서 온라인으로 전환 시 동기화
    if (wasOffline && !_isOffline) {
      try {
        await _reflectionService.syncOfflineData();
        // 학급 데이터 다시 로드
        if (_selectedClass.isNotEmpty) {
          selectClassAndWeek(_selectedClass, _selectedWeek);
        }
      } catch (e) {
        print('자동 동기화 오류: $e');
      }
    }

    notifyListeners();
  }

  // 성찰 질문 목록 로드
  Future<void> _loadReflectionQuestions() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 임시로 하드코딩된 reflectionCards 사용
      // 나중에 Firebase에서 로드하도록 수정 예정
      _reflectionCards = reflectionCards;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  // 선택된 성찰 ID 설정
  void selectReflection(int id) {
    _selectedReflectionId = id;
    notifyListeners();
  }

  // 학급과 주차 선택 및 성찰 데이터 구독
  void selectClassAndWeek(String className, int week) {
    // 이전 구독 취소
    _reflectionsSubscription?.cancel();

    _selectedClass = className;
    _selectedWeek = week;
    _isLoading = true;
    _error = '';
    notifyListeners();

    // 네트워크 상태 확인
    _reflectionService.isNetworkAvailable().then((isOnline) {
      _isOffline = !isOnline;

      // 성찰 데이터 구독
      _reflectionsSubscription =
          _reflectionService.getClassReflections(className, week).listen(
        (submissionsList) {
          _submissions = submissionsList;
          _updateSubmissionStatus(submissionsList);
          _isLoading = false;
          notifyListeners();
        },
        onError: (e) {
          _isLoading = false;
          _error = e.toString();
          _isOffline = true;
          notifyListeners();
        },
      );
    });
  }

  // 제출 현황 업데이트
  void _updateSubmissionStatus(List<FirebaseReflectionModel> submissions) {
    _submissionStatus.clear();

    for (var submission in submissions) {
      _submissionStatus[submission.studentId] = true;
    }

    notifyListeners();
  }

  // 성찰 보고서 제출
  Future<void> submitReflection(ReflectionSubmission submission) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      // 기존 ReflectionSubmission과 호환되도록 필드 구성
      await _reflectionService.submitReflection(
        studentId: submission.studentId,
        studentName: submission.studentName,
        className: submission.className,
        group: submission.group,
        reflectionId: submission.reflectionId,
        week: submission.week,
        questions: reflectionCards
            .firstWhere((r) => r.id == submission.reflectionId)
            .questions,
        answers: submission.answers,
      );

      // 제출 상태 업데이트
      _submissionStatus[submission.studentId] = true;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = _isOffline
          ? "오프라인 상태: 변경사항은 로컬에 저장되었으며 네트워크 연결 시 동기화됩니다."
          : "제출 오류: $e";
      notifyListeners();
    }
  }

  // 학생의 성찰 보고서 제출 여부 확인
  Future<bool> hasSubmitted(String studentId, int reflectionId) async {
    try {
      final reflection = await _reflectionService.getStudentReflection(
          studentId, reflectionId);
      return reflection != null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // 학생의 성찰 보고서 가져오기
  Future<ReflectionSubmission?> getSubmission(
      String studentId, int reflectionId) async {
    try {
      final reflection = await _reflectionService.getStudentReflection(
          studentId, reflectionId);

      if (reflection == null) {
        return ReflectionSubmission(
          studentId: studentId,
          reflectionId: reflectionId,
          week: reflectionCards.firstWhere((r) => r.id == reflectionId).week,
          answers: {},
          submittedDate: DateTime.now(),
        );
      }

      return ReflectionSubmission(
        studentId: reflection.studentId,
        reflectionId: reflectionId,
        week: reflection.week,
        answers: reflection.answers,
        submittedDate: reflection.submittedDate,
        studentName: reflection.studentName,
        className: reflection.className,
        group: reflection.group,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // 오프라인 데이터 동기화
  Future<void> syncOfflineData() async {
    if (!_isOffline) return;

    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      await _reflectionService.syncOfflineData();

      // 성공 후 데이터 다시 로드
      if (_selectedClass.isNotEmpty) {
        selectClassAndWeek(_selectedClass, _selectedWeek);
      }

      _isOffline = false;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = "동기화 오류: $e";
      notifyListeners();
    }
  }

  // 성찰 보고서 엑셀 다운로드 URL 생성
  Future<String> generateExcelDownloadUrl() async {
    if (_selectedClass.isEmpty) {
      throw Exception("학급이 선택되지 않았습니다");
    }

    if (_isOffline) {
      throw Exception("네트워크 연결이 필요합니다");
    }

    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      _downloadUrl = await _reflectionService.generateReflectionExcel(
          _selectedClass, _selectedWeek);
      _isLoading = false;
      notifyListeners();
      return _downloadUrl!;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // 현재 주차 설정
  void setCurrentWeek(int week) {
    _selectedWeek = week;
    notifyListeners();

    // 성찰 데이터 다시 로드
    if (_selectedClass.isNotEmpty) {
      selectClassAndWeek(_selectedClass, week);
    }
  }
}
