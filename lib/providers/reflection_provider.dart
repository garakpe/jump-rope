// lib/providers/reflection_provider.dart
import 'package:flutter/material.dart';
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
  String _error = '';
  String? _downloadUrl;

  List<FirebaseReflectionModel> get submissions => _submissions;
  List<ReflectionModel> get reflectionCards => _reflectionCards;
  int get selectedReflectionId => _selectedReflectionId;
  bool get isLoading => _isLoading;
  String get error => _error;
  String? get downloadUrl => _downloadUrl;

  // 생성자에서 성찰 질문 로드
  ReflectionProvider() {
    _loadReflectionQuestions();

    // 샘플 데이터 생성 (개발용)
    _reflectionService.createSampleReflections();
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
    _selectedClass = className;
    _selectedWeek = week;
    _isLoading = true;
    notifyListeners();

    _reflectionService.getClassReflections(className, week).listen(
        (submissionsList) {
      _submissions = submissionsList;
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    });
  }

  // 성찰 보고서 제출
  Future<void> submitReflection(ReflectionSubmission submission) async {
    _isLoading = true;
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

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
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

  // 성찰 보고서 엑셀 다운로드 URL 생성
  Future<String> generateExcelDownloadUrl() async {
    if (_selectedClass.isEmpty) {
      throw Exception("학급이 선택되지 않았습니다");
    }

    _isLoading = true;
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
}
