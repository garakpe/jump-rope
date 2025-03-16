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
  int _activeReflectionTypes = 3; // 기본값: 모든 성찰 유형 활성화
  final Map<int, DateTime?> _deadlines = {}; // 성찰 유형별 마감일

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

// 학급별 활성화된 성찰 유형 마스크 가져오기
  Future<int> getActiveReflectionMask(String classId) async {
    try {
      // 파이어베이스 연동 코드 - 학급 정보 포함
      DocumentSnapshot doc = await _firestore
          .collection('app_settings')
          .doc('reflection_settings_$classId') // 학급별 문서 ID
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // 마스크가 있으면 마스크 사용, 없으면 activeReflectionTypes로 변환
        if (data.containsKey('activeReflectionMask')) {
          return data['activeReflectionMask'];
        } else if (data.containsKey('activeReflectionTypes')) {
          // 이전 방식으로 저장된 데이터를 마스크로 변환
          int types = data['activeReflectionTypes'];
          int mask = 0;
          for (int i = 0; i < types; i++) {
            mask |= (1 << i);
          }
          return mask;
        }
      }

      return 1; // 기본값: 초기 성찰만
    } catch (e) {
      print('활성화된 성찰 유형 마스크 가져오기 오류: $e');
      return 1; // 기본값: 초기 성찰만
    }
  }

  // 추가: 설정 변경 스트림 제공
  Stream<DocumentSnapshot> getReflectionSettingsStream() {
    return _firestore
        .collection('app_settings')
        .doc('reflection_settings')
        .snapshots();
  }

// 학급별 설정 변경 스트림 제공
  Stream<Map<String, dynamic>> getSettingsStream(String classId) {
    return _firestore
        .collection('app_settings')
        .doc('reflection_settings_$classId') // 학급별 문서 ID
        .snapshots()
        .map((snapshot) =>
            snapshot.exists ? (snapshot.data() as Map<String, dynamic>) : {});
  }

// 학급별 성찰 유형 마스크 설정
  Future<void> setActiveReflectionMask(String classId, int mask) async {
    try {
      // 파이어베이스 연동 코드 - 학급 정보 포함
      await _firestore
          .collection('app_settings')
          .doc('reflection_settings_$classId') // 학급별 문서 ID
          .set({
        'activeReflectionMask': mask,
        // 하위 호환성을 위해 activeReflectionTypes도 저장
        'activeReflectionTypes': _countActiveBits(mask),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('활성화된 성찰 유형 마스크 설정 오류: $e');
      throw Exception('설정 저장 중 오류가 발생했습니다: $e');
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

  // 활성화된 성찰 유형 가져오기
  Future<int> getActiveReflectionTypes() async {
    try {
      // 파이어베이스 연동 코드
      DocumentSnapshot doc = await _firestore
          .collection('app_settings')
          .doc('reflection_settings')
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['activeReflectionTypes'] ?? 3;
      }

      return _activeReflectionTypes;
    } catch (e) {
      print('활성화된 성찰 유형 정보 가져오기 오류: $e');
      // 오류 발생 시 로컬 값 반환
      return _activeReflectionTypes;
    }
  }

  // 활성화된 성찰 유형 설정 (교사 전용)
  Future<void> setActiveReflectionTypes(int types) async {
    if (types < 1 || types > 3) {
      throw Exception('성찰 유형은 1~3 사이여야 합니다');
    }

    try {
      // 파이어베이스 연동 코드
      await _firestore
          .collection('app_settings')
          .doc('reflection_settings')
          .set({
        'activeReflectionTypes': types,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _activeReflectionTypes = types;
    } catch (e) {
      print('활성화된 성찰 유형 설정 오류: $e');
      // 로컬 구현
      _activeReflectionTypes = types;
      throw Exception('설정 저장 중 오류가 발생했습니다: $e');
    }
  }

// 학급별 마감일 정보 가져오기
  Future<Map<int, DateTime?>> getDeadlines(String classId) async {
    try {
      // 파이어베이스 연동 코드 - 학급 정보 포함
      DocumentSnapshot doc = await _firestore
          .collection('app_settings')
          .doc('reflection_settings_$classId') // 학급별 문서 ID
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        Map<String, dynamic> deadlinesData = data['deadlines'] ?? {};

        Map<int, DateTime?> result = {};
        deadlinesData.forEach((key, value) {
          int reflectionType = int.tryParse(key) ?? 0;
          if (reflectionType > 0 && value != null) {
            if (value is Timestamp) {
              result[reflectionType] = value.toDate();
            } else if (value is String) {
              try {
                result[reflectionType] = DateTime.parse(value);
              } catch (e) {
                print('마감일 파싱 오류: $e');
              }
            }
          }
        });

        return result;
      }

      return {};
    } catch (e) {
      print('마감일 정보 가져오기 오류: $e');
      return {};
    }
  }

// 학급별 마감일 설정
  Future<void> setDeadline(
      String classId, int reflectionType, DateTime? deadline) async {
    if (reflectionType < 1 || reflectionType > 3) {
      throw Exception('성찰 유형은 1~3 사이여야 합니다');
    }

    try {
      // 파이어베이스 연동 코드 - 학급 정보 포함
      await _firestore
          .collection('app_settings')
          .doc('reflection_settings_$classId') // 학급별 문서 ID
          .set({
        'deadlines': {
          reflectionType.toString():
              deadline != null ? Timestamp.fromDate(deadline) : null,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('마감일 설정 오류: $e');
      throw Exception('마감일 설정 중 오류가 발생했습니다: $e');
    }
  }

  // 성찰 보고서 제출
  Future<String> submitReflection({
    required String studentId,
    required String studentName,
    required String grade,
    required String classNum, // classNum 파라미터 추가
    required String studentNum, // studentNum 파라미터 추가
    required int group,
    required int reflectionId,
    required List<String> questions,
    required Map<String, String> answers,
  }) async {
    print("Service - 성찰 제출 시작: $studentId, 유형: $reflectionId");

    // 파이어베이스 연동 코드
    final reflectionData = {
      'studentId': studentId,
      'studentName': studentName,
      'grade': grade,
      'classNum': classNum, // classNum 필드 추가
      'studentNum': studentNum,
      'group': group,
      'reflectionId': reflectionId,
      'week': 0, // 사용하지 않는 필드이지만 호환성을 위해 유지
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
        grade,
        classNum, // classNum 전달
        "",
        group,
        reflectionId,
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
        grade,
        classNum, // classNum 전달
        "",
        group,
        reflectionId,
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

  // 학급의 성찰 유형별 보고서 가져오기
  Stream<List<FirebaseReflectionModel>> getClassReflections(
      String grade, int reflectionType) {
    try {
      // 파이어베이스 연동 코드
      return _firestore
          .collection('reflections')
          .where('grade', isEqualTo: grade)
          .where('reflectionId', isEqualTo: reflectionType)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => FirebaseReflectionModel.fromFirestore(doc))
              .toList());
    } catch (e) {
      print('성찰 보고서 목록 조회 오류: $e');

      // 로컬 구현
      final classReflections = _reflectionsByClass[grade] ?? [];
      final typeReflections = classReflections
          .where((r) => r.reflectionId == reflectionType)
          .toList();
      return Stream.value(typeReflections);
    }
  }

// lib/services/reflection_service.dart 수정

  Future<Map<String, int>> getSubmissionStatsByClass(
      String classId, int reflectionType) async {
    Map<String, int> stats = {
      'total': 0, // 전체 학생 수
      'submitted': 0, // 제출한 학생 수
      'rejected': 0, // 반려된 학생 수
      'accepted': 0, // 승인된 학생 수
    };

    try {
      // 클래스 ID가 없거나 비어있는 경우 빈 통계 반환
      if (classId.isEmpty) {
        return stats;
      }

      // 학급의 전체 학생 수 조회 - classNum으로 필터링
      QuerySnapshot studentsSnapshot = await _firestore
          .collection('students')
          .where('classNum', isEqualTo: classId)
          .get();

      stats['total'] = studentsSnapshot.docs.length;

      // 제출 현황 조회 - classNum과 reflectionType으로 필터링
      QuerySnapshot reflectionsSnapshot = await _firestore
          .collection('reflections')
          .where('classNum', isEqualTo: classId)
          .where('reflectionId', isEqualTo: reflectionType)
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
      return stats; // 오류 시 기본값 반환
    }
  }

  // 성찰 보고서 엑셀 다운로드 URL 생성
  Future<String> generateReflectionExcel(
      String grade, int reflectionType) async {
    try {
      // 실제 구현은 Cloud Functions를 통해 진행
      // 현재는 임시 구현으로 가짜 URL 반환

      // 모든 제출 데이터 가져오기
      QuerySnapshot snapshot = await _firestore
          .collection('reflections')
          .where('grade', isEqualTo: grade)
          .where('reflectionId', isEqualTo: reflectionType)
          .get();

      // 이 부분에서 Cloud Functions를 호출하여 Excel 생성 요청
      // 실제 코드는 Firebase 프로젝트에 따라 다름

      String reflectionTypeName = "";
      switch (reflectionType) {
        case 1:
          reflectionTypeName = "초기성찰";
          break;
        case 2:
          reflectionTypeName = "중기성찰";
          break;
        case 3:
          reflectionTypeName = "최종성찰";
          break;
        default:
          reflectionTypeName = "성찰";
      }

      // 임시 URL 반환
      return 'https://example.com/download/reflection_${grade}_${reflectionTypeName}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
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
      String grade,
      String classNum, // classNum 파라미터 추가
      String studentNum, // studentNum 파라미터 추가
      int group,
      int reflectionId,
      List<String> questions,
      Map<String, String> answers,
      DateTime submittedDate,
      ReflectionStatus status) {
    final reflection = FirebaseReflectionModel(
      id: id,
      studentId: studentId,
      studentName: studentName,
      grade: grade,
      classNum: classNum, // classNum 필드 할당
      studentNum: studentNum, // studentNum 필드 할당
      group: group,
      week: 0, // 사용하지 않는 필드이지만 모델 호환성을 위해 유지
      questions: questions,
      answers: answers,
      submittedDate: submittedDate,
      status: status,
    );

    // 클래스 목록에서 기존 항목이 있는지 확인
    if (_reflectionsByClass.containsKey(grade)) {
      final index = _reflectionsByClass[grade]!.indexWhere(
          (r) => r.studentId == studentId && r.reflectionId == reflectionId);

      if (index >= 0) {
        // 기존 항목 업데이트
        _reflectionsByClass[grade]![index] = reflection;
      } else {
        // 새 항목 추가
        _reflectionsByClass[grade]!.add(reflection);
      }
    } else {
      // 새 클래스 목록 생성
      _reflectionsByClass[grade] = [reflection];
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
    _activeReflectionTypes = 3; // 모든 성찰 유형 활성화

    // 마감일 설정을 현재 날짜보다 후로 변경 (MVP를 위해)
    _deadlines[1] =
        DateTime.now().add(const Duration(days: 30)); // 초기 성찰은 한달 후 마감
    _deadlines[2] =
        DateTime.now().add(const Duration(days: 30)); // 중기 성찰도 한달 후 마감
    _deadlines[3] =
        DateTime.now().add(const Duration(days: 30)); // 최종 성찰도 한달 후 마감

    // 초기 성찰 샘플
    final initialQuestions =
        reflectionCards.firstWhere((card) => card.id == 1).questions;

    final sampleReflection1 = FirebaseReflectionModel(
      id: 'sample1',
      studentId: '12345',
      studentName: '김철수',
      grade: '1',
      classNum: '1-1', // classNum 필드 추가
      group: 1,
      week: 0, // 사용하지 않음
      reflectionId: 1,
      questions: initialQuestions,
      answers: {
        initialQuestions[0]: '줄넘기를 잘하고 친구들과 협동하는 것입니다.',
        initialQuestions[1]: '매일 연습하고 선생님 말씀을 잘 듣는 것이 필요합니다.',
        initialQuestions[2]: '기본적인 뛰기는 할 수 있지만 더 연습이 필요합니다.',
        initialQuestions[3]: '친구들을 도와주고 함께 연습하는 것입니다.',
      },
      submittedDate: DateTime.now().subtract(const Duration(days: 2)),
      status: ReflectionStatus.accepted,
    );

    // 중기 성찰 샘플
    final midQuestions =
        reflectionCards.firstWhere((card) => card.id == 2).questions;

    final sampleReflection2 = FirebaseReflectionModel(
      id: 'sample2',
      studentId: '67890',
      studentName: '홍길동',
      grade: '1',
      classNum: '1-2', // classNum 필드 추가
      group: 2,
      week: 0, // 사용하지 않음
      reflectionId: 2,
      questions: midQuestions,
      answers: {
        midQuestions[0]: '양발 모아 뛰기가 가장 어려웠습니다.',
        midQuestions[1]: '매일 10분씩 연습했습니다.',
        midQuestions[2]: '서로 응원해주는 점은 좋았지만, 시간 관리가 부족했습니다.',
        midQuestions[3]: '이중 뛰기에 도전하고 싶습니다.',
      },
      submittedDate: DateTime.now().subtract(const Duration(days: 1)),
      status: ReflectionStatus.submitted,
    );

    // 반려된 성찰 샘플
    final sampleReflection3 = FirebaseReflectionModel(
      id: 'sample3',
      studentId: '54321',
      studentName: '이영희',
      grade: '1',
      classNum: '1-3', // classNum 필드 추가
      group: 3,
      week: 0, // 사용하지 않음
      reflectionId: 1,
      questions: initialQuestions,
      answers: {
        initialQuestions[0]: '잘 모르겠습니다.',
        initialQuestions[1]: '열심히 하겠습니다.',
        initialQuestions[2]: '보통이요.',
        initialQuestions[3]: '열심히 하는 역할입니다.',
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
