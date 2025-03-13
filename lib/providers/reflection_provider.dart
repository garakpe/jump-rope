// lib/providers/reflection_provider.dart
import 'package:flutter/material.dart';
import '../models/reflection_model.dart';
import '../models/firebase_models.dart';
import '../services/reflection_service.dart';

class ReflectionProvider extends ChangeNotifier {
  final ReflectionService _reflectionService = ReflectionService();

  // 성찰 데이터 관련 상태
  List<ReflectionModel> _reflectionCards = [];
  List<FirebaseReflectionModel> _submissions = [];
  Map<int, DateTime?> _deadlines = {};
  int _activeWeeks = 1; // 현재 활성화된 주차

  // UI 상태
  bool _isLoading = false;
  String _error = '';
  String? _downloadUrl;

  // 선택 상태
  int _selectedReflectionId = 0;
  String _selectedClass = '';
  int _selectedWeek = 1;

  // 캐시 상태
  final Map<String, Map<int, FirebaseReflectionModel>> _studentReflections = {};
  final Map<String, ReflectionStatus> _reflectionStatuses = {};

  // Getters
  List<FirebaseReflectionModel> get submissions => _submissions;
  List<ReflectionModel> get reflectionCards => _reflectionCards;
  int get selectedReflectionId => _selectedReflectionId;
  int get activeWeeks => _activeWeeks;
  bool get isLoading => _isLoading;
  String get error => _error;
  String? get downloadUrl => _downloadUrl;
  Map<int, DateTime?> get deadlines => _deadlines;

  // 생성자: 기본 데이터 로드
  ReflectionProvider() {
    _initializeData();
  }

  // 초기 데이터 로드
  Future<void> _initializeData() async {
    await _loadReflectionQuestions();
    await _loadActiveWeeks();
    await _loadDeadlines();
  }

  // 성찰 질문 목록 로드
  Future<void> _loadReflectionQuestions() async {
    _setLoading(true);

    try {
      // 기본적으로 하드코딩된 reflectionCards 사용
      _reflectionCards = reflectionCards;

      // 실제 환경에서는 서비스를 통해 Firebase에서 로드
      // _reflectionCards = await _reflectionService.getReflectionQuestions();

      _setLoading(false);
    } catch (e) {
      _handleError('성찰 질문 로드 실패', e);
    }
  }

  // 활성화된 주차 정보 로드
  Future<void> _loadActiveWeeks() async {
    try {
      int weeks = await _reflectionService.getActiveWeeks();
      if (weeks > 0) {
        _activeWeeks = weeks;
        notifyListeners();
      }
    } catch (e) {
      // 활성화 주차 로드 실패는 UI에 영향을 크게 주지 않으므로 로그만 출력
      print('활성화된 주차 정보 로드 실패: $e');
    }
  }

  // 주차별 마감 정보 로드
  Future<void> _loadDeadlines() async {
    try {
      final deadlines = await _reflectionService.getDeadlines();
      _deadlines = deadlines;
      notifyListeners();
    } catch (e) {
      print('마감 정보 로드 실패: $e');
    }
  }

  // 선택된 성찰 ID 설정
  void selectReflection(int id) {
    _selectedReflectionId = id;
    notifyListeners();
  }

  // 활성화된 주차 설정 (교사 전용)
  Future<void> setActiveWeeks(int weeks) async {
    if (weeks < 1 || weeks > 3) return;

    _setLoading(true);

    try {
      await _reflectionService.setActiveWeeks(weeks);
      _activeWeeks = weeks;
      _setLoading(false);
    } catch (e) {
      _handleError('주차 활성화 설정 실패', e);
    }
  }

  // 주차별 마감일 설정
  Future<void> setWeekDeadline(int week, DateTime? deadline) async {
    if (week < 1 || week > 3) return;

    _setLoading(true);

    try {
      await _reflectionService.setDeadline(week, deadline);
      _deadlines[week] = deadline;
      _setLoading(false);
    } catch (e) {
      _handleError('마감일 설정 실패', e);
    }
  }

  // 학급과 주차 선택 및 성찰 데이터 구독
  void selectClassAndWeek(String className, int week) {
    _selectedClass = className;
    _selectedWeek = week;
    _setLoading(true, notify: true);
    _clearError(); // private 메서드 호출

    _reflectionService.getClassReflections(className, week).listen(
        (submissionsList) {
      _submissions = submissionsList;
      _setLoading(false);
    }, onError: (e) {
      _handleError('성찰 데이터 로드 실패', e);
    });
  }

  // 성찰 제출
  Future<void> submitReflection(ReflectionSubmission submission) async {
    _setLoading(true);
    _clearError();

    try {
      print(
          "Provider - 성찰 제출 시작: ${submission.studentId}, 주차: ${submission.week}");

      // 성찰 카드 찾기
      final reflectionCard = _findReflectionCard(submission);

      // 로컬 캐시에 저장
      _cacheSubmission(submission, reflectionCard);

      // 서버에 저장
      await _reflectionService.submitReflection(
        studentId: submission.studentId,
        studentName: submission.studentName,
        className: submission.className,
        group: submission.group,
        reflectionId: submission.reflectionId,
        week: submission.week,
        questions: reflectionCard.questions,
        answers: submission.answers,
      );

      print("Provider - 성찰 제출 성공");

      // 상태 업데이트
      _updateSubmissionStatus(submission.studentId, submission.reflectionId,
          ReflectionStatus.submitted);

      _setLoading(false);
    } catch (e) {
      print("Provider - 성찰 제출 실패: $e");
      _error = '서버 저장 실패: $e - 로컬에 임시 저장됨';
      _setLoading(false);
    }
  }

  // 성찰 카드 찾기 도우미 메서드
  ReflectionModel _findReflectionCard(ReflectionSubmission submission) {
    try {
      return reflectionCards.firstWhere(
        (r) => r.id == submission.reflectionId,
        orElse: () => ReflectionModel(
          id: submission.reflectionId,
          title: "${submission.week}주차 성찰",
          week: submission.week,
          questions: submission.answers.keys.toList(),
        ),
      );
    } catch (e) {
      print("성찰 카드 찾기 실패: $e");
      return ReflectionModel(
        id: submission.reflectionId,
        title: "${submission.week}주차 성찰",
        week: submission.week,
        questions: submission.answers.keys.toList(),
      );
    }
  }

  // 제출 상태 업데이트 메서드
  void _updateSubmissionStatus(
      String studentId, int reflectionId, ReflectionStatus status) {
    // 상태 맵에 저장
    _reflectionStatuses['${studentId}_$reflectionId'] = status;
    notifyListeners();
  }

  // 로컬 캐시에 제출 데이터 저장
  void _cacheSubmission(
      ReflectionSubmission submission, ReflectionModel reflectionCard) {
    try {
      print("로컬에 임시 저장: ${submission.studentId}, 주차: ${submission.week}");

      // 상태 업데이트
      _updateSubmissionStatus(submission.studentId, submission.reflectionId,
          ReflectionStatus.submitted);

      // 학생 ID별 맵 초기화
      if (!_studentReflections.containsKey(submission.studentId)) {
        _studentReflections[submission.studentId] = {};
      }

      // 리플렉션 모델 생성
      final reflection = FirebaseReflectionModel(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        studentId: submission.studentId,
        studentName: submission.studentName,
        className: submission.className,
        group: submission.group,
        week: submission.week,
        questions: reflectionCard.questions,
        answers: submission.answers,
        submittedDate: submission.submittedDate,
        status: ReflectionStatus.submitted,
      );

      // 캐시에 저장
      _studentReflections[submission.studentId]![submission.reflectionId] =
          reflection;

      print("로컬 저장 성공");
    } catch (e) {
      print("로컬 저장 실패: $e");
      rethrow;
    }
  }

  // 성찰 보고서 반려
  Future<void> rejectReflection(String reflectionId, String reason) async {
    _setLoading(true);

    try {
      // 서버 반려 처리
      try {
        await _reflectionService.rejectReflection(reflectionId, reason);
      } catch (e) {
        print('서버 반려 처리 실패: $e - 로컬에만 반영됨');
      }

      // 로컬 데이터 업데이트
      _updateLocalRejection(reflectionId, reason);

      _setLoading(false);
    } catch (e) {
      _handleError('성찰 반려 처리 실패', e);
      rethrow;
    }
  }

  // 로컬 데이터에서 반려 처리
  void _updateLocalRejection(String reflectionId, String reason) {
    // 제출 목록에서 찾기
    for (var i = 0; i < _submissions.length; i++) {
      if (_submissions[i].id == reflectionId) {
        // 상태 업데이트
        final submission = _submissions[i];
        final updatedSubmission = submission.copyWith(
          status: ReflectionStatus.rejected,
          rejectionReason: reason,
        );

        // 목록 업데이트
        _submissions[i] = updatedSubmission;

        // 학생별 캐시 업데이트
        _updateStudentCache(submission, updatedSubmission);

        // 상태 업데이트
        _reflectionStatuses['${submission.studentId}_${submission.week}'] =
            ReflectionStatus.rejected;

        break;
      }
    }
  }

  // 학생 캐시 업데이트
  void _updateStudentCache(FirebaseReflectionModel oldSubmission,
      FirebaseReflectionModel newSubmission) {
    if (_studentReflections.containsKey(oldSubmission.studentId)) {
      for (var week in _studentReflections[oldSubmission.studentId]!.keys) {
        if (_studentReflections[oldSubmission.studentId]![week]!.id ==
            oldSubmission.id) {
          _studentReflections[oldSubmission.studentId]![week] = newSubmission;
          break;
        }
      }
    }
  }

  // 학생의 성찰 보고서 제출 여부 확인
  Future<bool> hasSubmitted(String studentId, int reflectionId) async {
    try {
      final reflection = await _reflectionService.getStudentReflection(
          studentId, reflectionId);
      return reflection != null;
    } catch (e) {
      _setError('제출 여부 확인 실패: $e');
      return false;
    }
  }

  // 학생의 성찰 보고서 상태 확인
  Future<ReflectionStatus> getSubmissionStatus(
      String studentId, int reflectionId) async {
    try {
      // 먼저 로컬 캐시 확인
      final cacheKey = '${studentId}_$reflectionId';
      if (_reflectionStatuses.containsKey(cacheKey)) {
        return _reflectionStatuses[cacheKey]!;
      }

      // 로컬 캐시에 없으면 서비스 호출
      final status =
          await _reflectionService.getReflectionStatus(studentId, reflectionId);

      // 캐시에 저장
      _reflectionStatuses[cacheKey] = status;

      return status;
    } catch (e) {
      _setError('상태 확인 실패: $e');
      return ReflectionStatus.notSubmitted;
    }
  }

  // 학생의 성찰 보고서 가져오기
  Future<ReflectionSubmission?> getSubmission(
      String studentId, int reflectionId) async {
    try {
      // 먼저 로컬 캐시 확인
      if (_isInStudentCache(studentId, reflectionId)) {
        return _createSubmissionFromCache(studentId, reflectionId);
      }

      // 로컬 캐시에 없으면 서비스 호출
      final reflection = await _reflectionService.getStudentReflection(
          studentId, reflectionId);

      if (reflection == null) {
        return _createEmptySubmission(studentId, reflectionId);
      }

      return _createSubmissionFromFirebase(reflection, reflectionId);
    } catch (e) {
      _setError('성찰 데이터 조회 실패: $e');
      return null;
    }
  }

  // 캐시에 있는지 확인
  bool _isInStudentCache(String studentId, int reflectionId) {
    return _studentReflections.containsKey(studentId) &&
        _studentReflections[studentId]!.containsKey(reflectionId);
  }

  // 캐시에서 제출 데이터 생성
  ReflectionSubmission _createSubmissionFromCache(
      String studentId, int reflectionId) {
    final reflection = _studentReflections[studentId]![reflectionId]!;

    return ReflectionSubmission(
      studentId: reflection.studentId,
      reflectionId: reflectionId,
      week: reflection.week,
      answers: reflection.answers,
      submittedDate: reflection.submittedDate,
      studentName: reflection.studentName,
      className: reflection.className,
      group: reflection.group,
      status: reflection.status,
      rejectionReason: reflection.rejectionReason,
    );
  }

  // 빈 제출 데이터 생성
  ReflectionSubmission _createEmptySubmission(
      String studentId, int reflectionId) {
    return ReflectionSubmission(
      studentId: studentId,
      reflectionId: reflectionId,
      week: reflectionCards.firstWhere((r) => r.id == reflectionId).week,
      answers: {},
      submittedDate: DateTime.now(),
    );
  }

  // Firebase 모델에서 제출 데이터 생성
  ReflectionSubmission _createSubmissionFromFirebase(
      FirebaseReflectionModel reflection, int reflectionId) {
    return ReflectionSubmission(
      studentId: reflection.studentId,
      reflectionId: reflectionId,
      week: reflection.week,
      answers: reflection.answers,
      submittedDate: reflection.submittedDate,
      studentName: reflection.studentName,
      className: reflection.className,
      group: reflection.group,
      status: reflection.status,
      rejectionReason: reflection.rejectionReason,
    );
  }

  // 주차별 학급 제출 현황 가져오기
  Future<Map<String, int>> getSubmissionStatsByClass(String className) async {
    _setLoading(true);

    try {
      final stats =
          await _reflectionService.getSubmissionStatsByClass(className);
      _setLoading(false);
      return stats;
    } catch (e) {
      _handleError('제출 현황 조회 실패', e);
      return {};
    }
  }

  // 성찰 보고서 엑셀 다운로드 URL 생성
  Future<String> generateExcelDownloadUrl() async {
    if (_selectedClass.isEmpty) {
      throw Exception("학급이 선택되지 않았습니다");
    }

    _setLoading(true);

    try {
      _downloadUrl = await _reflectionService.generateReflectionExcel(
          _selectedClass, _selectedWeek);
      _setLoading(false);
      return _downloadUrl!;
    } catch (e) {
      _handleError('엑셀 다운로드 URL 생성 실패', e);
      rethrow;
    }
  }

  // 성찰 보고서 승인
  Future<void> approveReflection(String reflectionId) async {
    _setLoading(true);

    try {
      // 승인 처리 API 호출 (실제 서비스에 구현 필요)
      // await _reflectionService.approveReflection(reflectionId);

      // 로컬 상태 업데이트
      _updateLocalApproval(reflectionId);

      _setLoading(false);
    } catch (e) {
      _handleError('성찰 승인 처리 실패', e);
      rethrow;
    }
  }

  // 로컬 데이터 승인 처리
  void _updateLocalApproval(String reflectionId) {
    for (var i = 0; i < _submissions.length; i++) {
      if (_submissions[i].id == reflectionId) {
        // 상태 업데이트
        final submission = _submissions[i];
        final updatedSubmission = submission.copyWith(
          status: ReflectionStatus.accepted,
        );

        // 목록 업데이트
        _submissions[i] = updatedSubmission;

        // 학생별 캐시 업데이트
        _updateStudentCache(submission, updatedSubmission);

        // 상태 업데이트
        _reflectionStatuses['${submission.studentId}_${submission.week}'] =
            ReflectionStatus.accepted;

        break;
      }
    }
  }

  // 로딩 상태 설정
  void _setLoading(bool loading, {bool notify = true}) {
    _isLoading = loading;
    if (notify) notifyListeners();
  }

  // 에러 설정
  void _setError(String errorMessage) {
    _error = errorMessage;
    notifyListeners();
  }

  // 에러 핸들링
  void _handleError(String context, dynamic error) {
    print('$context: $error');
    _error = '$context: $error';
    _isLoading = false;
    notifyListeners();
  }

  // 오류 메시지 초기화 (private 버전)
  void _clearError() {
    _error = '';
  }

  // 오류 메시지 초기화 (public 버전)
  void clearError() {
    _error = '';
    notifyListeners();
  }
}
