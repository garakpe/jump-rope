// lib/services/reflection_service.dart
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/firebase_models.dart';
import '../models/reflection_model.dart';

class ReflectionService {
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 로컬 구현을 위한 데이터
  final Map<String, List<FirebaseReflectionModel>> _reflectionsByClass = {};
  final Map<String, Map<int, FirebaseReflectionModel>> _studentReflections = {};

  ReflectionService() {
    // 샘플 데이터 초기화
    createSampleReflections();
  }

  // 학생의 성찰 보고서 제출
  Future<String> submitReflection({
    required String studentId,
    required String studentName,
    required String className,
    required int group,
    required int reflectionId,
    required int week,
    required List<String> questions,
    required Map<String, String> answers,
  }) async {
    // 파이어베이스 연동 코드 (주석 처리)
    // final reflectionData = {
    //   'studentId': studentId,
    //   'studentName': studentName,
    //   'className': className,
    //   'group': group,
    //   'reflectionId': reflectionId,
    //   'week': week,
    //   'questions': questions,
    //   'answers': answers,
    //   'submittedDate': FieldValue.serverTimestamp(),
    // };
    //
    // try {
    //   // Firestore에 저장 시도
    //   DocumentReference docRef =
    //       await _firestore.collection('reflections').add(reflectionData);
    //   return docRef.id;
    // } catch (e) {
    //   print('성찰 보고서 제출 오류: $e');
    //
    //   // 오류 발생 시 임시 ID 반환 (개발 중에만 사용)
    //   return 'temp_id_${DateTime.now().millisecondsSinceEpoch}';
    // }

    // 로컬 구현
    try {
      final submittedDate = DateTime.now();
      final id = 'reflection_${DateTime.now().millisecondsSinceEpoch}';

      final reflection = FirebaseReflectionModel(
        id: id,
        studentId: studentId,
        studentName: studentName,
        className: className,
        group: group,
        week: week,
        questions: questions,
        answers: answers,
        submittedDate: submittedDate,
      );

      // 학급별 성찰 목록에 추가
      if (!_reflectionsByClass.containsKey(className)) {
        _reflectionsByClass[className] = [];
      }
      _reflectionsByClass[className]!.add(reflection);

      // 학생별 성찰 목록에 추가
      if (!_studentReflections.containsKey(studentId)) {
        _studentReflections[studentId] = {};
      }
      _studentReflections[studentId]![reflectionId] = reflection;

      return id;
    } catch (e) {
      print('성찰 보고서 제출 오류: $e');
      return 'temp_id_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // 학생의 성찰 보고서 가져오기
  Future<FirebaseReflectionModel?> getStudentReflection(
      String studentId, int reflectionId) async {
    try {
      // 파이어베이스 연동 코드 (주석 처리)
      // QuerySnapshot querySnapshot = await _firestore
      //     .collection('reflections')
      //     .where('studentId', isEqualTo: studentId)
      //     .where('reflectionId', isEqualTo: reflectionId)
      //     .limit(1)
      //     .get();
      //
      // if (querySnapshot.docs.isEmpty) {
      //   return null;
      // }
      //
      // return FirebaseReflectionModel.fromFirestore(querySnapshot.docs.first);

      // 로컬 구현
      if (!_studentReflections.containsKey(studentId)) {
        return null;
      }

      return _studentReflections[studentId]?[reflectionId];
    } catch (e) {
      print('성찰 보고서 조회 오류: $e');
      return null;
    }
  }

  // 학급의 주차별 성찰 보고서 가져오기
  Stream<List<FirebaseReflectionModel>> getClassReflections(
      String className, int week) {
    try {
      // 파이어베이스 연동 코드 (주석 처리)
      // return _firestore
      //     .collection('reflections')
      //     .where('className', isEqualTo: className)
      //     .where('week', isEqualTo: week)
      //     .snapshots()
      //     .map((snapshot) => snapshot.docs
      //         .map((doc) => FirebaseReflectionModel.fromFirestore(doc))
      //         .toList());

      // 로컬 구현
      final classReflections = _reflectionsByClass[className] ?? [];
      final weekReflections =
          classReflections.where((r) => r.week == week).toList();
      return Stream.value(weekReflections);
    } catch (e) {
      print('성찰 보고서 목록 조회 오류: $e');
      // 오류 발생 시 빈 목록 반환
      return Stream.value([]);
    }
  }

  // 성찰 보고서 엑셀 다운로드 URL 생성 (임시 구현)
  Future<String> generateReflectionExcel(String className, int week) async {
    // 실제 구현은 Firebase Storage 이용
    // 현재는 개발용 임시 URL 반환
    await Future.delayed(const Duration(seconds: 1)); // 임시 지연
    return 'https://example.com/download/reflection_${className}_week$week.xlsx';
  }

  // 성찰 질문 목록 초기화 (앱 초기화 시 사용)
  Future<void> initializeReflectionQuestions() async {
    try {
      // 파이어베이스 연동 코드 (주석 처리)
      // final questionsDoc = await _firestore
      //     .collection('app_data')
      //     .doc('reflection_questions')
      //     .get();
      //
      // if (!questionsDoc.exists) {
      //   await _firestore
      //       .collection('app_data')
      //       .doc('reflection_questions')
      //       .set({
      //     'reflections': reflectionCards
      //         .map((card) => {
      //               'id': card.id,
      //               'title': card.title,
      //               'week': card.week,
      //               'questions': card.questions,
      //             })
      //         .toList(),
      //   });
      // }

      // 로컬 구현 - 이미 reflectionCards가 있으므로 별도 작업 필요 없음
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      print('성찰 질문 초기화 오류: $e');
    }
  }

  // 샘플 성찰 데이터 생성 (개발용)
  void createSampleReflections() {
    // 1주차 성찰 샘플
    final week1Questions =
        reflectionCards.firstWhere((card) => card.week == 1).questions;

    final sampleReflection1 = FirebaseReflectionModel(
      id: 'sample1',
      studentId: '12345',
      studentName: '김철수',
      className: '1',
      group: 1,
      week: 1,
      questions: week1Questions,
      answers: {
        week1Questions[0]: '줄넘기를 잘하고 친구들과 협동하는 것입니다.',
        week1Questions[1]: '매일 연습하고 선생님 말씀을 잘 듣는 것이 필요합니다.',
        week1Questions[2]: '기본적인 뛰기는 할 수 있지만 더 연습이 필요합니다.',
        week1Questions[3]: '친구들을 도와주고 함께 연습하는 것입니다.',
      },
      submittedDate: DateTime.now().subtract(const Duration(days: 2)),
    );

    // 2주차 성찰 샘플
    final week2Questions =
        reflectionCards.firstWhere((card) => card.week == 2).questions;

    final sampleReflection2 = FirebaseReflectionModel(
      id: 'sample2',
      studentId: '67890',
      studentName: '홍길동',
      className: '1',
      group: 2,
      week: 2,
      questions: week2Questions,
      answers: {
        week2Questions[0]: '양발 모아 뛰기가 가장 어려웠습니다.',
        week2Questions[1]: '매일 10분씩 연습했습니다.',
        week2Questions[2]: '서로 응원해주는 점은 좋았지만, 시간 관리가 부족했습니다.',
        week2Questions[3]: '이중 뛰기에 도전하고 싶습니다.',
      },
      submittedDate: DateTime.now().subtract(const Duration(days: 1)),
    );

    // 샘플 데이터 저장
    if (!_reflectionsByClass.containsKey('1')) {
      _reflectionsByClass['1'] = [];
    }
    _reflectionsByClass['1']!.add(sampleReflection1);
    _reflectionsByClass['1']!.add(sampleReflection2);

    // 학생별 데이터 저장
    if (!_studentReflections.containsKey('12345')) {
      _studentReflections['12345'] = {};
    }
    _studentReflections['12345']![1] = sampleReflection1;

    if (!_studentReflections.containsKey('67890')) {
      _studentReflections['67890'] = {};
    }
    _studentReflections['67890']![2] = sampleReflection2;
  }
}
