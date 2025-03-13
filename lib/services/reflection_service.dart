// lib/services/reflection_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/firebase_models.dart';
import '../models/reflection_model.dart';

class ReflectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 로컬 구현을 위한 데이터
  final Map<String, List<FirebaseReflectionModel>> _reflectionsByClass = {};
  final Map<String, Map<int, FirebaseReflectionModel>> _studentReflections = {};
  final Map<String, ReflectionStatus> _reflectionStatuses = {};
  int _activeWeeks = 1; // 기본값: 1주차만 활성화
  final Map<int, DateTime?> _deadlines = {}; // 주차별 마감일

  ReflectionService() {
    // 샘플 데이터 초기화
    createSampleReflections();
  }

  // ID 유효성 검사 도우미 메서드
  void _validateId(String id, String operation) {
    if (id.isEmpty) {
      throw Exception('$operation 실패: 성찰 보고서 ID가 비어있습니다.');
    }
  }

  // 활성화된 주차 가져오기
  Future<int> getActiveWeeks() async {
    try {
      // 파이어베이스 연동 코드
      DocumentSnapshot doc = await _firestore
          .collection('app_settings')
          .doc('reflection_settings')
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['activeWeeks'] ?? 1;
      }

      return _activeWeeks;
    } catch (e) {
      print('활성화된 주차 정보 가져오기 오류: $e');
      // 오류 발생 시 로컬 값 반환
      return _activeWeeks;
    }
  }

  // 활성화된 주차 설정 (교사 전용)
  Future<void> setActiveWeeks(int weeks) async {
    if (weeks < 1 || weeks > 3) {
      throw Exception('주차는 1~3 사이여야 합니다');
    }

    try {
      // 파이어베이스 연동 코드
      await _firestore
          .collection('app_settings')
          .doc('reflection_settings')
          .set({
        'activeWeeks': weeks,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _activeWeeks = weeks;
    } catch (e) {
      print('활성화된 주차 설정 오류: $e');
      // 로컬 구현
      _activeWeeks = weeks;
      throw Exception('설정 저장 중 오류가 발생했습니다: $e');
    }
  }

  // 마감일 정보 가져오기
  Future<Map<int, DateTime?>> getDeadlines() async {
    try {
      // 파이어베이스 연동 코드
      DocumentSnapshot doc = await _firestore
          .collection('app_settings')
          .doc('reflection_settings')
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        Map<String, dynamic> deadlinesData = data['deadlines'] ?? {};

        Map<int, DateTime?> result = {};
        deadlinesData.forEach((key, value) {
          int week = int.tryParse(key) ?? 0;
          if (week > 0 && value != null) {
            if (value is Timestamp) {
              result[week] = value.toDate();
            } else if (value is String) {
              try {
                result[week] = DateTime.parse(value);
              } catch (e) {
                print('마감일 파싱 오류: $e');
              }
            }
          }
        });

        return result;
      }

      return _deadlines;
    } catch (e) {
      print('마감일 정보 가져오기 오류: $e');
      // 오류 발생 시 로컬 값 반환
      return _deadlines;
    }
  }

  // 마감일 설정 (교사 전용)
  Future<void> setDeadline(int week, DateTime? deadline) async {
    if (week < 1 || week > 3) {
      throw Exception('주차는 1~3 사이여야 합니다');
    }

    try {
      // 파이어베이스 연동 코드
      await _firestore
          .collection('app_settings')
          .doc('reflection_settings')
          .set({
        'deadlines': {
          week.toString():
              deadline != null ? Timestamp.fromDate(deadline) : null,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _deadlines[week] = deadline;
    } catch (e) {
      print('마감일 설정 오류: $e');
      // 로컬 구현
      _deadlines[week] = deadline;
      throw Exception('마감일 설정 중 오류가 발생했습니다: $e');
    }
  }

  // 성찰 보고서 제출
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
    print("Service - 성찰 제출 시작: $studentId, 주차: $week");

    // 파이어베이스 연동 코드
    final reflectionData = {
      'studentId': studentId,
      'studentName': studentName,
      'className': className,
      'group': group,
      'reflectionId': reflectionId,
      'week': week,
      'questions': questions,
      'answers': answers,
      'submittedDate': FieldValue.serverTimestamp(),
      'status': 'submitted',
      'rejectionReason': null,
    };

    try {
      String docId = '';

      print("Firestore에 reflections 저장 시도");

      // 기존 문서 찾기 시도
      QuerySnapshot existingDocs = await _firestore
          .collection('reflections')
          .where('studentId', isEqualTo: studentId)
          .where('reflectionId', isEqualTo: reflectionId)
          .limit(1)
          .get();

      if (existingDocs.docs.isNotEmpty) {
        // 기존 문서 업데이트
        docId = existingDocs.docs.first.id;
        await _firestore
            .collection('reflections')
            .doc(docId)
            .update(reflectionData);
        print("Firestore의 기존 문서 업데이트 성공: $docId");
      } else {
        // 새 문서 생성
        DocumentReference docRef =
            await _firestore.collection('reflections').add(reflectionData);
        docId = docRef.id;
        print("Firestore에 새 문서 생성 성공: $docId");
      }

      // 로컬 캐시 업데이트
      _updateLocalReflection(
        docId,
        studentId,
        studentName,
        className,
        group,
        reflectionId,
        week,
        questions,
        answers,
        DateTime.now(), // 서버 타임스탬프를 사용할 수 없으므로 현재 시간 사용
        ReflectionStatus.submitted,
      );

      return docId;
    } catch (e) {
      print("Firestore 저장 실패. 상세 오류: $e");
      print(StackTrace.current);

      // 오류가 발생해도 사용자에게 피드백 제공을 위해 로컬 ID 반환
      String localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      print("로컬 ID 생성: $localId");

      // 로컬 캐시 업데이트
      _updateLocalReflection(
        localId,
        studentId,
        studentName,
        className,
        group,
        reflectionId,
        week,
        questions,
        answers,
        DateTime.now(),
        ReflectionStatus.submitted,
      );

      return localId;
    }
  }

  // 성찰 보고서 반려 (교사 전용)
  Future<void> rejectReflection(String reflectionId, String reason) async {
    _validateId(reflectionId, '성찰 보고서 반려');

    try {
      print('Service - 성찰 반려 시작: 문서 ID=$reflectionId, 사유=$reason');

      // 파이어베이스 연동 코드
      await _firestore.collection('reflections').doc(reflectionId).update({
        'status': 'rejected',
        'rejectionReason': reason,
        'rejectedAt': FieldValue.serverTimestamp()
      });

      print('Service - Firestore 반려 처리 성공');

      // 로컬 캐시 업데이트
      DocumentSnapshot doc =
          await _firestore.collection('reflections').doc(reflectionId).get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String studentId = data['studentId'] ?? '';
        int reflectionId = data['reflectionId'] ?? 0;

        if (studentId.isNotEmpty && reflectionId > 0) {
          _reflectionStatuses['${studentId}_$reflectionId'] =
              ReflectionStatus.rejected;
        }
      }
    } catch (e) {
      print('성찰 보고서 반려 오류: $e');
      throw Exception('성찰 보고서 반려 중 오류가 발생했습니다: $e');
    }
  }

  // 학생의 성찰 보고서 가져오기
  Future<FirebaseReflectionModel?> getStudentReflection(
      String studentId, int reflectionId) async {
    if (studentId.isEmpty) {
      throw Exception('학생 ID가 비어있습니다');
    }

    try {
      // 파이어베이스 연동 코드
      QuerySnapshot querySnapshot = await _firestore
          .collection('reflections')
          .where('studentId', isEqualTo: studentId)
          .where('reflectionId', isEqualTo: reflectionId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return FirebaseReflectionModel.fromFirestore(querySnapshot.docs.first);
    } catch (e) {
      print('성찰 보고서 조회 오류: $e');

      // 로컬 구현
      if (!_studentReflections.containsKey(studentId)) {
        return null;
      }

      return _studentReflections[studentId]?[reflectionId];
    }
  }

  // 성찰 보고서 승인 메서드
  Future<void> approveReflection(String reflectionId) async {
    _validateId(reflectionId, '성찰 보고서 승인');

    try {
      print('Service - 성찰 승인 시작: 문서 ID=$reflectionId');

      // 파이어베이스 연동 코드
      await _firestore.collection('reflections').doc(reflectionId).update(
          {'status': 'accepted', 'approvedAt': FieldValue.serverTimestamp()});

      print('Service - Firestore 승인 처리 성공');

      // 로컬 캐시 업데이트
      DocumentSnapshot doc =
          await _firestore.collection('reflections').doc(reflectionId).get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String studentId = data['studentId'] ?? '';
        int reflectionId = data['reflectionId'] ?? 0;

        if (studentId.isNotEmpty && reflectionId > 0) {
          _reflectionStatuses['${studentId}_$reflectionId'] =
              ReflectionStatus.accepted;
        }
      }
    } catch (e) {
      print('성찰 보고서 승인 오류: $e');
      throw Exception('성찰 보고서 승인 중 오류가 발생했습니다: $e');
    }
  }

  // 학생의 성찰 보고서 상태 확인
  Future<ReflectionStatus> getReflectionStatus(
      String studentId, int reflectionId) async {
    try {
      // 먼저 로컬 캐시 확인
      if (_reflectionStatuses.containsKey('${studentId}_$reflectionId')) {
        return _reflectionStatuses['${studentId}_$reflectionId']!;
      }

      // 파이어베이스 연동 코드
      QuerySnapshot querySnapshot = await _firestore
          .collection('reflections')
          .where('studentId', isEqualTo: studentId)
          .where('reflectionId', isEqualTo: reflectionId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return ReflectionStatus.notSubmitted;
      }

      Map<String, dynamic> data =
          querySnapshot.docs.first.data() as Map<String, dynamic>;

      String status = data['status'] ?? 'submitted';
      ReflectionStatus result;

      switch (status) {
        case 'submitted':
          result = ReflectionStatus.submitted;
          break;
        case 'rejected':
          result = ReflectionStatus.rejected;
          break;
        case 'accepted':
          result = ReflectionStatus.accepted;
          break;
        default:
          result = ReflectionStatus.notSubmitted;
          break;
      }

      // 로컬 캐시에 저장
      _reflectionStatuses['${studentId}_$reflectionId'] = result;

      return result;
    } catch (e) {
      print('성찰 보고서 상태 조회 오류: $e');

      // 로컬 구현
      return _reflectionStatuses['${studentId}_$reflectionId'] ??
          ReflectionStatus.notSubmitted;
    }
  }

  // 학급의 주차별 성찰 보고서 가져오기
  Stream<List<FirebaseReflectionModel>> getClassReflections(
      String className, int week) {
    try {
      // 파이어베이스 연동 코드
      return _firestore
          .collection('reflections')
          .where('className', isEqualTo: className)
          .where('week', isEqualTo: week)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => FirebaseReflectionModel.fromFirestore(doc))
              .toList());
    } catch (e) {
      print('성찰 보고서 목록 조회 오류: $e');

      // 로컬 구현
      final classReflections = _reflectionsByClass[className] ?? [];
      final weekReflections =
          classReflections.where((r) => r.week == week).toList();
      return Stream.value(weekReflections);
    }
  }

  // 학급별 제출 현황 통계 가져오기
  Future<Map<String, int>> getSubmissionStatsByClass(String className) async {
    Map<String, int> stats = {
      'total': 0, // 전체 학생 수
      'submitted': 0, // 제출한 학생 수
      'rejected': 0, // 반려된 학생 수
      'accepted': 0, // 승인된 학생 수
    };

    try {
      // 학생 수 조회
      QuerySnapshot studentsSnapshot = await _firestore
          .collection('students')
          .where('className', isEqualTo: className)
          .get();

      stats['total'] = studentsSnapshot.docs.length;

      // 제출 현황 조회
      QuerySnapshot reflectionsSnapshot = await _firestore
          .collection('reflections')
          .where('className', isEqualTo: className)
          .get();

      // 상태별 카운트
      for (var doc in reflectionsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String status = data['status'] ?? 'submitted';

        switch (status) {
          case 'submitted':
            stats['submitted'] = (stats['submitted'] ?? 0) + 1;
            break;
          case 'rejected':
            stats['rejected'] = (stats['rejected'] ?? 0) + 1;
            break;
          case 'accepted':
            stats['accepted'] = (stats['accepted'] ?? 0) + 1;
            break;
        }
      }

      return stats;
    } catch (e) {
      print('제출 현황 통계 조회 오류: $e');

      // 로컬 구현
      stats['total'] = 30; // 임의의 학생 수
      stats['submitted'] = 20;
      stats['rejected'] = 5;
      stats['accepted'] = 15;

      return stats;
    }
  }

  // 성찰 보고서 엑셀 다운로드 URL 생성
  Future<String> generateReflectionExcel(String className, int week) async {
    try {
      // 실제 구현은 Cloud Functions를 통해 진행
      // 현재는 임시 구현으로 가짜 URL 반환

      // 모든 제출 데이터 가져오기
      QuerySnapshot snapshot = await _firestore
          .collection('reflections')
          .where('className', isEqualTo: className)
          .where('week', isEqualTo: week)
          .get();

      // 이 부분에서 Cloud Functions를 호출하여 Excel 생성 요청
      // 실제 코드는 Firebase 프로젝트에 따라 다름

      // 임시 URL 반환
      return 'https://example.com/download/reflection_${className}_week${week}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    } catch (e) {
      print('엑셀 생성 오류: $e');
      throw Exception('엑셀 파일 생성 중 오류가 발생했습니다: $e');
    }
  }

  // 로컬 성찰 데이터 업데이트
  void _updateLocalReflection(
      String id,
      String studentId,
      String studentName,
      String className,
      int group,
      int reflectionId,
      int week,
      List<String> questions,
      Map<String, String> answers,
      DateTime submittedDate,
      ReflectionStatus status) {
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
      status: status,
    );

    // 클래스 목록에서 기존 항목이 있는지 확인
    if (_reflectionsByClass.containsKey(className)) {
      final index = _reflectionsByClass[className]!
          .indexWhere((r) => r.studentId == studentId && r.week == week);

      if (index >= 0) {
        // 기존 항목 업데이트
        _reflectionsByClass[className]![index] = reflection;
      } else {
        // 새 항목 추가
        _reflectionsByClass[className]!.add(reflection);
      }
    } else {
      // 새 클래스 목록 생성
      _reflectionsByClass[className] = [reflection];
    }

    // 학생별 목록 업데이트
    if (!_studentReflections.containsKey(studentId)) {
      _studentReflections[studentId] = {};
    }
    _studentReflections[studentId]![reflectionId] = reflection;

    // 상태 업데이트
    _reflectionStatuses['${studentId}_$reflectionId'] = status;
  }

  // 샘플 성찰 데이터 생성 (개발용)
  void createSampleReflections() {
    // 초기 설정값 세팅
    _activeWeeks = 3; // 모든 주차 활성화

    // 마감일 설정을 현재 날짜보다 후로 변경 (MVP를 위해)
    _deadlines[1] =
        DateTime.now().add(const Duration(days: 30)); // 1주차는 한달 후 마감
    _deadlines[2] =
        DateTime.now().add(const Duration(days: 30)); // 2주차도 한달 후 마감
    _deadlines[3] =
        DateTime.now().add(const Duration(days: 30)); // 3주차도 한달 후 마감

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
      status: ReflectionStatus.accepted,
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
      status: ReflectionStatus.submitted,
    );

    // 반려된 성찰 샘플
    final sampleReflection3 = FirebaseReflectionModel(
      id: 'sample3',
      studentId: '54321',
      studentName: '이영희',
      className: '1',
      group: 3,
      week: 1,
      questions: week1Questions,
      answers: {
        week1Questions[0]: '잘 모르겠습니다.',
        week1Questions[1]: '열심히 하겠습니다.',
        week1Questions[2]: '보통이요.',
        week1Questions[3]: '열심히 하는 역할입니다.',
      },
      submittedDate: DateTime.now().subtract(const Duration(days: 3)),
      status: ReflectionStatus.rejected,
      rejectionReason: '답변이 너무 짧습니다. 더 자세히 작성해주세요.',
    );

    // 샘플 데이터 저장
    if (!_reflectionsByClass.containsKey('1')) {
      _reflectionsByClass['1'] = [];
    }
    _reflectionsByClass['1']!.add(sampleReflection1);
    _reflectionsByClass['1']!.add(sampleReflection2);
    _reflectionsByClass['1']!.add(sampleReflection3);

    // 학생별 데이터 저장
    if (!_studentReflections.containsKey('12345')) {
      _studentReflections['12345'] = {};
    }
    _studentReflections['12345']![1] = sampleReflection1;

    if (!_studentReflections.containsKey('67890')) {
      _studentReflections['67890'] = {};
    }
    _studentReflections['67890']![2] = sampleReflection2;

    if (!_studentReflections.containsKey('54321')) {
      _studentReflections['54321'] = {};
    }
    _studentReflections['54321']![1] = sampleReflection3;

    // 상태 정보 설정
    _reflectionStatuses['12345_1'] = ReflectionStatus.accepted;
    _reflectionStatuses['67890_2'] = ReflectionStatus.submitted;
    _reflectionStatuses['54321_1'] = ReflectionStatus.rejected;
  }
}
