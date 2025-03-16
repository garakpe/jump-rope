// lib/providers/reflection_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/reflection_model.dart';
import '../models/firebase_models.dart';
import '../services/reflection_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReflectionProvider extends ChangeNotifier {
  final ReflectionService _reflectionService = ReflectionService();

  // 성찰 데이터 관련 상태
  List<ReflectionModel> _reflectionCards = [];
  List<FirebaseReflectionModel> _submissions = [];
  Map<int, DateTime?> _deadlines = {};
  int _activeReflectionTypes = 1; // 현재 활성화된 성찰 유형

  // UI 상태
  bool _isLoading = false;
  String _error = '';
  String? _downloadUrl;

  // 선택 상태
  int _selectedReflectionId = 0;
  String _selectedClass = '';
  int _selectedReflectionType = 1;

  // 캐시 상태
  final Map<String, Map<int, FirebaseReflectionModel>> _studentReflections = {};
  final Map<String, ReflectionStatus> _reflectionStatuses = {};

  // Getters
  List<FirebaseReflectionModel> get submissions => _submissions;
  List<ReflectionModel> get reflectionCards => _reflectionCards;
  int get selectedReflectionId => _selectedReflectionId;
  int get activeReflectionTypes => _activeReflectionTypes;
  bool get isLoading => _isLoading;
  String get error => _error;
  String? get downloadUrl => _downloadUrl;
  Map<int, DateTime?> get deadlines => _deadlines;
  String get selectedClass => _selectedClass;

  // 추가: 설정 변경 구독용 변수
  StreamSubscription? _settingsSubscription;

  // 생성자: 기본 데이터 로드
  ReflectionProvider() {
    _initializeData();
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel(); // 구독 취소
    super.dispose();
  }

  // 초기 데이터 로드
  Future<void> _initializeData() async {
    try {
      await Future.wait([
        _loadReflectionQuestions(),
        _loadActiveReflectionTypes(),
        _loadDeadlines(),
      ]);
    } catch (e) {
      _handleError('초기 데이터 로드 실패', e);
    }
  }

  // 설정 변경 구독 메서드 수정
  void _subscribeToSettingsChanges() {
    // 이전 구독 취소
    _settingsSubscription?.cancel();

    // 클래스가 선택되지 않았으면 리턴
    if (_selectedClass.isEmpty) return;

    print('설정 변경 구독 시작: 학급 $_selectedClass');

    // 학급별 설정 스트림 구독
    _settingsSubscription =
        _reflectionService.getSettingsStream(_selectedClass).listen((data) {
      bool shouldNotify = false;

      // 활성화된 성찰 유형 처리
      if (data.containsKey('activeReflectionMask')) {
        final newMask = data['activeReflectionMask'] as int;
        if (newMask != _activeReflectionMask) {
          _activeReflectionMask = newMask;
          _activeReflectionTypes = _countActiveBits(newMask);
          shouldNotify = true;
          print('성찰 활성화 마스크 업데이트: $_activeReflectionMask, 학급: $_selectedClass');
        }
      }

      // 마감일 정보 처리
      if (data.containsKey('deadlines')) {
        Map<String, dynamic> deadlinesData = data['deadlines'] ?? {};
        Map<int, DateTime?> newDeadlines = {};

        deadlinesData.forEach((key, value) {
          int reflectionType = int.tryParse(key) ?? 0;
          if (reflectionType > 0 && value != null) {
            if (value is Timestamp) {
              newDeadlines[reflectionType] = value.toDate();
            } else if (value is String) {
              try {
                newDeadlines[reflectionType] = DateTime.parse(value);
              } catch (e) {
                print('마감일 파싱 오류: $e');
              }
            }
          }
        });

        // 마감일이 변경되었는지 확인
        bool deadlinesChanged = false;
        if (newDeadlines.length != _deadlines.length) {
          deadlinesChanged = true;
        } else {
          newDeadlines.forEach((type, date) {
            if (!_deadlines.containsKey(type) ||
                _deadlines[type]?.millisecondsSinceEpoch !=
                    date?.millisecondsSinceEpoch) {
              deadlinesChanged = true;
            }
          });
        }

        if (deadlinesChanged) {
          _deadlines = newDeadlines;
          shouldNotify = true;
          print('마감일 정보 업데이트됨, 학급: $_selectedClass');
        }
      }

      // 변경사항이 있으면 알림
      if (shouldNotify) {
        notifyListeners(); // UI 갱신 트리거
      }
    });
  }

  // 성찰 질문 목록 로드
  Future<void> _loadReflectionQuestions() async {
    _setLoading(true);

    try {
      // 기본적으로 하드코딩된 reflectionCards 사용
      _reflectionCards = reflectionCards;
      _setLoading(false);
    } catch (e) {
      _handleError('성찰 질문 로드 실패', e);
    }
  }

  // 비트마스크 상수 추가
  static const int INITIAL_REFLECTION = 1; // 2^0 = 1
  static const int MID_REFLECTION = 2; // 2^1 = 2
  static const int FINAL_REFLECTION = 4; // 2^2 = 4

  // 기존 _activeReflectionTypes 유지하면서 비트마스크 추가
  int _activeReflectionMask = INITIAL_REFLECTION; // 기본값: 초기 성찰만 활성화

  // 게터 추가
  int get activeReflectionMask => _activeReflectionMask;

  // 특정 성찰 유형이 활성화되었는지 확인하는 메서드 수정
  bool isReflectionTypeActive(int reflectionType) {
    if (reflectionType < 1 || reflectionType > 3) return false;

    // 선택된 학급이 없는 경우 기본값
    if (_selectedClass.isEmpty) {
      return reflectionType == 1; // 초기 성찰만 활성화
    }

    int mask = _activeReflectionMask;
    return (mask & (1 << (reflectionType - 1))) != 0;
  }

  // 성찰 유형 활성화/비활성화 메서드 수정
  Future<void> toggleReflectionType(int reflectionType, bool isActive) async {
    if (reflectionType < 1 || reflectionType > 3) return;

    // 선택된 학급이 없는 경우 작업 취소
    if (_selectedClass.isEmpty) {
      throw Exception('학급이 선택되지 않았습니다.');
    }

    int mask = _activeReflectionMask;

    if (isActive) {
      mask |= (1 << (reflectionType - 1)); // 활성화
    } else {
      mask &= ~(1 << (reflectionType - 1)); // 비활성화
    }

    try {
      // 학급별 설정으로 변경
      await _reflectionService.setActiveReflectionMask(_selectedClass, mask);

      // 호환성을 위해 _activeReflectionTypes도 업데이트
      _activeReflectionMask = mask;
      _activeReflectionTypes = _countActiveBits(_activeReflectionMask);

      notifyListeners();
    } catch (e) {
      print('성찰 유형 상태 변경 실패: $e');
      throw Exception('성찰 유형 상태 변경 중 오류가 발생했습니다: $e');
    }
  }

  // 활성화된 비트 수 계산 도우미 메서드
  int _countActiveBits(int mask) {
    int count = 0;
    for (int i = 0; i < 3; i++) {
      if ((mask & (1 << i)) != 0) {
        count++;
      }
    }
    return count;
  }

  // 기존 _loadActiveReflectionTypes 메서드 수정
  Future<void> _loadActiveReflectionTypes() async {
    try {
      // 선택된 학급이 없는 경우 기본값 설정
      if (_selectedClass.isEmpty) {
        _activeReflectionMask = 1; // 초기 성찰만 활성화
        _activeReflectionTypes = 1;
        notifyListeners();
        return;
      }

      // 학급별 마스크 로드
      int mask =
          await _reflectionService.getActiveReflectionMask(_selectedClass);
      if (mask > 0) {
        _activeReflectionMask = mask;
        _activeReflectionTypes = _countActiveBits(mask);
        notifyListeners();
        return;
      }

      // 기존 방식으로 로드 (하위 호환성)
      // 이 부분은 선택적으로 삭제 가능
      int types = await _reflectionService.getActiveReflectionTypes();
      if (types > 0) {
        _activeReflectionTypes = types;

        // 이전 방식으로 마스크 설정
        _activeReflectionMask = 0;
        for (int i = 0; i < types; i++) {
          _activeReflectionMask |= (1 << i);
        }

        notifyListeners();
      }
    } catch (e) {
      print('활성화된 성찰 유형 정보 로드 실패: $e');
    }
  }

  // 성찰 유형별 마감일 정보 로드 수정
  Future<void> _loadDeadlines() async {
    try {
      // 선택된 학급이 없는 경우 빈 맵 반환
      if (_selectedClass.isEmpty) {
        _deadlines = {};
        notifyListeners();
        return;
      }

      final deadlines = await _reflectionService.getDeadlines(_selectedClass);
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

  // 활성화된 성찰 유형 설정 (교사 전용)
  Future<void> setActiveReflectionTypes(int types) async {
    if (types < 1 || types > 3) return;

    _setLoading(true);

    try {
      await _reflectionService.setActiveReflectionTypes(types);
      _activeReflectionTypes = types;
      _setLoading(false);
    } catch (e) {
      _handleError('성찰 유형 활성화 설정 실패', e);
    }
  }

  // 성찰 유형의 마감 여부 확인 메서드 추가
  bool isReflectionDeadlinePassed(int reflectionType) {
    final deadline = _deadlines[reflectionType];
    return deadline != null && deadline.isBefore(DateTime.now());
  }

  // 성찰 유형별 마감일 설정 수정
  Future<void> setDeadline(int reflectionType, DateTime? deadline) async {
    if (reflectionType < 1 || reflectionType > 3) return;

    // 선택된 학급이 없는 경우 작업 취소
    if (_selectedClass.isEmpty) {
      throw Exception('학급이 선택되지 않았습니다.');
    }

    _setLoading(true);

    try {
      // 학급별 마감일 설정
      await _reflectionService.setDeadline(
          _selectedClass, reflectionType, deadline);
      _deadlines[reflectionType] = deadline;
      _setLoading(false);
    } catch (e) {
      _handleError('마감일 설정 실패', e);
    }
  }

  // 학급과 성찰 유형 선택 및 성찰 데이터 구독 메서드 수정
  void selectClassAndReflectionType(String grade, int reflectionType) {
    // 학급 변경 시 설정 구독도 변경
    bool classChanged = _selectedClass != grade;

    _selectedClass = grade;
    _selectedReflectionType = reflectionType;
    _setLoading(true, notify: true);
    _clearError();

    // 학급이 변경되었으면 활성화 타입과 마감일 정보 새로 로드
    if (classChanged) {
      _loadActiveReflectionTypes();
      _loadDeadlines();
      _subscribeToSettingsChanges(); // 설정 변경 구독 재설정
    }

    // 성찰 데이터 구독
    _reflectionService.getClassReflections(grade, reflectionType).listen(
        (submissionsList) {
      _submissions = submissionsList;
      _setLoading(false);
    }, onError: (e) {
      _handleError('성찰 데이터 로드 실패', e);
    });
  }

  // 성찰 카드 찾기 도우미 메서드
  ReflectionModel _findReflectionCard(ReflectionSubmission submission) {
    try {
      return reflectionCards.firstWhere(
        (r) => r.id == submission.reflectionId,
        orElse: () => ReflectionModel(
          id: submission.reflectionId,
          title: _getReflectionTitle(submission.reflectionId),
          questions: submission.answers.keys.toList(),
        ),
      );
    } catch (e) {
      print("성찰 카드 찾기 실패: $e");
      return ReflectionModel(
        id: submission.reflectionId,
        title: _getReflectionTitle(submission.reflectionId),
        questions: submission.answers.keys.toList(),
      );
    }
  }

  // 성찰 유형에 따른 제목 반환
  String _getReflectionTitle(int reflectionId) {
    switch (reflectionId) {
      case 1:
        return "초기 성찰";
      case 2:
        return "중기 성찰";
      case 3:
        return "최종 성찰";
      default:
        return "성찰";
    }
  }

  // 마감 여부 변경 시 UI 갱신을 위한 간단한 메서드
  void refreshSettings() {
    notifyListeners();
  }

  // 특정 학급의 설정 정보 강제 새로고침
  Future<void> refreshClassSettings(String classId) async {
    if (classId.isEmpty) return;

    _setLoading(true);

    try {
      // 선택된 학급 설정
      _selectedClass = classId;

      // 활성화 타입과 마감일 정보 새로 로드
      await _loadActiveReflectionTypes();
      await _loadDeadlines();

      // 설정 변경 구독 재설정
      _subscribeToSettingsChanges();

      _setLoading(false);
    } catch (e) {
      _handleError('설정 새로고침 실패', e);
    }
  }

  Future<void> submitReflection(ReflectionSubmission submission) async {
    _setLoading(true);
    _clearError();

    try {
      print(
          "Provider - 성찰 제출 시작: ${submission.studentId}, 유형: ${submission.reflectionId}");

      // 성찰 카드 찾기
      final reflectionCard = _findReflectionCard(submission);

      // submission 객체에서 직접 classNum 값을 사용
      // classNum 값이 null이거나 비어있으면 grade을 사용
      String classNumToUse = submission.classNum;
      if (classNumToUse.isEmpty && submission.grade.isNotEmpty) {
        classNumToUse = submission.grade;
      }

      // 서버에 저장하고 문서 ID 받기
      String docId = await _reflectionService.submitReflection(
        studentId: submission.studentId,
        studentName: submission.studentName,
        grade: submission.grade,
        classNum: classNumToUse, // 여기에 처리된 classNum 추가
        studentNum: submission.studentNum, // studentNum 추가
        group: submission.group,
        reflectionId: submission.reflectionId,
        questions: reflectionCard.questions,
        answers: submission.answers,
      );

      // ID를 포함한 submission 생성
      final updatedSubmission = submission.copyWith(id: docId);

      // 로컬 캐시에 저장
      _cacheSubmission(updatedSubmission, reflectionCard);

      print("Provider - 성찰 제출 성공");

      // 상태 업데이트
      _updateSubmissionStatus(updatedSubmission.studentId,
          updatedSubmission.reflectionId, ReflectionStatus.submitted);

      _setLoading(false);
    } catch (e) {
      print("Provider - 성찰 제출 실패: $e");
      _error = '서버 저장 실패: $e - 로컬에 임시 저장됨';
      _setLoading(false);
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
      print(
          "로컬에 임시 저장: ${submission.studentId}, 유형: ${submission.reflectionId}, ID: ${submission.id}");

      // 상태 업데이트
      _updateSubmissionStatus(submission.studentId, submission.reflectionId,
          ReflectionStatus.submitted);

      // 학생 ID별 맵 초기화
      if (!_studentReflections.containsKey(submission.studentId)) {
        _studentReflections[submission.studentId] = {};
      }

      // 문서 ID 처리
      final documentId = submission.id.isNotEmpty
          ? submission.id
          : 'local_${DateTime.now().millisecondsSinceEpoch}';

      // 리플렉션 모델 생성
      final reflection = FirebaseReflectionModel(
        id: documentId,
        studentId: submission.studentId,
        studentName: submission.studentName,
        grade: submission.grade,
        classNum: submission.classNum, // classNum 필드 추가
        studentNum: submission.studentNum,
        group: submission.group,
        week: 0, // 필요없는 필드지만 모델에 있으므로 기본값 설정
        questions: reflectionCard.questions,
        answers: submission.answers,
        submittedDate: submission.submittedDate,
        status: ReflectionStatus.submitted,
      );

      // 캐시에 저장
      _studentReflections[submission.studentId]![submission.reflectionId] =
          reflection;

      print("로컬 저장 성공 (ID: $documentId)");
    } catch (e) {
      print("로컬 저장 실패: $e");
      rethrow;
    }
  }

  // 성찰 보고서 반려 메서드
  Future<void> rejectReflection(String reflectionId, String reason) async {
    if (reflectionId.isEmpty) {
      _setError('반려 실패: 성찰 보고서 ID가 없습니다');
      return;
    }

    _setLoading(true);

    try {
      print("Provider - 성찰 반려 시작. ID: $reflectionId, 사유: $reason");

      // 서버 반려 처리
      await _reflectionService.rejectReflection(reflectionId, reason);

      // 로컬 데이터 업데이트
      _updateLocalRejection(reflectionId, reason);

      print("Provider - 성찰 반려 성공");
      _setLoading(false);
    } catch (e) {
      _handleError('성찰 반려 처리 실패', e);
      rethrow;
    }
  }

  // 로컬 데이터에서 반려 처리 업데이트
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

        // 상태 업데이트 (학생용 화면에 반영되도록)
        _reflectionStatuses[
                '${submission.studentId}_${submission.reflectionId}'] =
            ReflectionStatus.rejected;

        break;
      }
    }

    notifyListeners(); // UI 갱신을 위해 추가
  }

  // 학생 캐시 업데이트
  void _updateStudentCache(FirebaseReflectionModel oldSubmission,
      FirebaseReflectionModel newSubmission) {
    if (_studentReflections.containsKey(oldSubmission.studentId)) {
      for (var reflectionType
          in _studentReflections[oldSubmission.studentId]!.keys) {
        if (_studentReflections[oldSubmission.studentId]![reflectionType]!.id ==
            oldSubmission.id) {
          _studentReflections[oldSubmission.studentId]![reflectionType] =
              newSubmission;
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

      // 로컬 캐시에 없으면 서비스 호출 시도
      try {
        final reflection = await _reflectionService.getStudentReflection(
            studentId, reflectionId);

        if (reflection == null) {
          // 파이어베이스에 데이터가 없으면 빈 양식 생성
          return _createEmptySubmission(studentId, reflectionId);
        }

        return _createSubmissionFromFirebase(reflection, reflectionId);
      } catch (e) {
        print('성찰 서비스 조회 실패: $e - 빈 양식을 생성합니다.');
        // 서비스 호출 실패 시 빈 양식 반환
        return _createEmptySubmission(studentId, reflectionId);
      }
    } catch (e) {
      print('성찰 데이터 조회 중 오류 발생: $e');
      _setError('성찰 데이터 조회 실패: $e');
      // 오류 발생해도 빈 양식 반환
      return _createEmptySubmission(studentId, reflectionId);
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
      id: reflection.id,
      studentId: reflection.studentId,
      reflectionId: reflectionId,
      week: 0, // 사용하지 않는 필드
      answers: reflection.answers,
      submittedDate: reflection.submittedDate,
      studentName: reflection.studentName,
      grade: reflection.grade,
      classNum: reflection.classNum, // classNum 필드 추가
      studentNum: reflection.studentNum,
      group: reflection.group,
      status: reflection.status,
      rejectionReason: reflection.rejectionReason,
    );
  }

  // 빈 제출 데이터 생성
  ReflectionSubmission _createEmptySubmission(
      String studentId, int reflectionId) {
    // reflectionId에 해당하는 모델 찾기, 없으면 첫 번째 모델 사용
    final ReflectionModel reflection = reflectionCards.firstWhere(
      (r) => r.id == reflectionId,
      orElse: () => reflectionCards.first,
    );

    // 아이디 생성 (로컬 임시 ID)
    final String tmpId = 'empty_${DateTime.now().millisecondsSinceEpoch}';

    return ReflectionSubmission(
      id: tmpId,
      studentId: studentId,
      reflectionId: reflectionId,
      week: 0, // 사용하지 않는 필드
      answers: {},
      submittedDate: DateTime.now(),
      classNum: '', // classNum 필드 추가 (빈 값으로)
      studentNum: '',
    );
  }

  // Firebase 모델에서 제출 데이터 생성
  ReflectionSubmission _createSubmissionFromFirebase(
      FirebaseReflectionModel reflection, int reflectionId) {
    return ReflectionSubmission(
      id: reflection.id,
      studentId: reflection.studentId,
      reflectionId: reflectionId,
      week: 0, // 사용하지 않는 필드
      answers: reflection.answers,
      submittedDate: reflection.submittedDate,
      studentName: reflection.studentName,
      grade: reflection.grade,
      classNum: reflection.classNum, // classNum 필드 추가
      studentNum: reflection.studentNum,
      group: reflection.group,
      status: reflection.status,
      rejectionReason: reflection.rejectionReason,
    );
  }

  Future<Map<String, int>> getSubmissionStatsByClass(
      String grade, int reflectionType) async {
    _setLoading(true);

    try {
      final stats = await _reflectionService.getSubmissionStatsByClass(
          grade, reflectionType);
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
          _selectedClass, _selectedReflectionType);
      _setLoading(false);
      return _downloadUrl!;
    } catch (e) {
      _handleError('엑셀 다운로드 URL 생성 실패', e);
      rethrow;
    }
  }

  // 성찰 보고서 승인 메서드
  Future<void> approveReflection(String reflectionId) async {
    if (reflectionId.isEmpty) {
      _setError('승인 실패: 성찰 보고서 ID가 없습니다');
      return;
    }

    _setLoading(true);

    try {
      print("Provider - 성찰 승인 시작. ID: $reflectionId");

      // 승인 처리 API 호출
      await _reflectionService.approveReflection(reflectionId);

      // 로컬 상태 업데이트
      _updateLocalApproval(reflectionId);

      print("Provider - 성찰 승인 성공");
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
        _reflectionStatuses[
                '${submission.studentId}_${submission.reflectionId}'] =
            ReflectionStatus.accepted;

        break;
      }
    }

    notifyListeners();
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

  // 모든 성찰 유형 통합 엑셀 다운로드 URL 생성
  Future<String> generateAllReflectionTypesExcelUrl() async {
    if (_selectedClass.isEmpty) {
      throw Exception("학급이 선택되지 않았습니다");
    }

    _setLoading(true);

    try {
      _downloadUrl = await _reflectionService
          .generateAllReflectionTypesExcel(_selectedClass);
      _setLoading(false);
      return _downloadUrl!;
    } catch (e) {
      _handleError('통합 엑셀 파일 생성 중 오류가 발생했습니다', e);
      rethrow;
    }
  }

  // 모든 성찰 유형 통합 엑셀 다운로드 메서드
  Future<String> generateAllReflectionTypesExcel() async {
    if (_selectedClass.isEmpty) {
      throw Exception("학급이 선택되지 않았습니다");
    }

    _setLoading(true);

    try {
      final fileName = await _reflectionService
          .generateAllReflectionTypesExcel(_selectedClass);
      _setLoading(false);
      return fileName;
    } catch (e) {
      _handleError('통합 엑셀 파일 생성 중 오류가 발생했습니다', e);
      rethrow;
    }
  }
}
