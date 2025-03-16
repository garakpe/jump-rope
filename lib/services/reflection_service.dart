// lib/services/reflection_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/firebase_models.dart';
import '../models/reflection_model.dart';

class ReflectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ///----- 도우미 메서드 -----///

  // DocumentReference 가져오기 도우미 메서드
  DocumentReference _getSettingsRef(String classId) {
    return _firestore
        .collection('app_settings')
        .doc('reflection_settings_$classId');
  }

  // 기본 성찰 컬렉션 참조 도우미
  CollectionReference get _reflectionsRef =>
      _firestore.collection('reflections');

  // ID 유효성 검사 도우미 메서드
  void _validateId(String id, String operation) {
    if (id.isEmpty) {
      throw Exception('$operation 실패: 성찰 보고서 ID가 비어있습니다.');
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

  // 성찰 유형에 따른 이름 반환
  String _getReflectionTypeName(int reflectionType) {
    switch (reflectionType) {
      case 1:
        return "초기성찰";
      case 2:
        return "중기성찰";
      case 3:
        return "최종성찰";
      default:
        return "성찰";
    }
  }

  ///----- 설정 관련 메서드 -----///

  // 학급별 설정 변경 스트림 제공
  Stream<Map<String, dynamic>> getSettingsStream(String classId) {
    return _getSettingsRef(classId).snapshots().map((snapshot) =>
        snapshot.exists ? (snapshot.data() as Map<String, dynamic>) : {});
  }

  // 학급별 활성화된 성찰 유형 마스크 가져오기
  Future<int> getActiveReflectionMask(String classId) async {
    try {
      DocumentSnapshot doc = await _getSettingsRef(classId).get();

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

  // 학급별 성찰 유형 마스크 설정
  Future<void> setActiveReflectionMask(String classId, int mask) async {
    try {
      await _getSettingsRef(classId).set({
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

  // 이전 버전 호환성: 활성화된 성찰 유형 가져오기
  Future<int> getActiveReflectionTypes() async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('app_settings')
          .doc('reflection_settings')
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['activeReflectionTypes'] ?? 1;
      }

      return 1; // 기본값: 초기 성찰만
    } catch (e) {
      print('활성화된 성찰 유형 정보 가져오기 오류: $e');
      return 1; // 기본값: 초기 성찰만
    }
  }

  // 이전 버전 호환성: 활성화된 성찰 유형 설정 (교사 전용)
  Future<void> setActiveReflectionTypes(int types) async {
    if (types < 1 || types > 3) {
      throw Exception('성찰 유형은 1~3 사이여야 합니다');
    }

    try {
      await _firestore
          .collection('app_settings')
          .doc('reflection_settings')
          .set({
        'activeReflectionTypes': types,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('활성화된 성찰 유형 설정 오류: $e');
      throw Exception('설정 저장 중 오류가 발생했습니다: $e');
    }
  }

  // 학급별 마감일 정보 가져오기
  Future<Map<int, DateTime?>> getDeadlines(String classId) async {
    try {
      DocumentSnapshot doc = await _getSettingsRef(classId).get();

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
      await _getSettingsRef(classId).set({
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

  ///----- 성찰 보고서 관련 메서드 -----///

  // 성찰 보고서 제출
  Future<String> submitReflection({
    required String studentId,
    required String studentName,
    required String grade,
    required String classNum,
    required String studentNum,
    required int group,
    required int reflectionId,
    required List<String> questions,
    required Map<String, String> answers,
  }) async {
    print("Service - 성찰 제출 시작: $studentId, 유형: $reflectionId");

    final reflectionData = {
      'studentId': studentId,
      'studentName': studentName,
      'grade': grade,
      'classNum': classNum,
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

      // 기존 문서 찾기 시도
      QuerySnapshot existingDocs = await _reflectionsRef
          .where('studentId', isEqualTo: studentId)
          .where('reflectionId', isEqualTo: reflectionId)
          .limit(1)
          .get();

      if (existingDocs.docs.isNotEmpty) {
        // 기존 문서 업데이트
        docId = existingDocs.docs.first.id;
        await _reflectionsRef.doc(docId).update(reflectionData);
        print("Firestore의 기존 문서 업데이트 성공: $docId");
      } else {
        // 새 문서 생성
        DocumentReference docRef = await _reflectionsRef.add(reflectionData);
        docId = docRef.id;
        print("Firestore에 새 문서 생성 성공: $docId");
      }

      return docId;
    } catch (e) {
      print("Firestore 저장 실패. 상세 오류: $e");
      print(StackTrace.current);
      throw Exception("성찰 보고서 저장 중 오류가 발생했습니다: $e");
    }
  }

  // 성찰 보고서 반려 (교사 전용)
  Future<void> rejectReflection(String reflectionId, String reason) async {
    _validateId(reflectionId, '성찰 보고서 반려');

    try {
      print('Service - 성찰 반려 시작: 문서 ID=$reflectionId, 사유=$reason');

      await _reflectionsRef.doc(reflectionId).update({
        'status': 'rejected',
        'rejectionReason': reason,
        'rejectedAt': FieldValue.serverTimestamp()
      });

      print('Service - Firestore 반려 처리 성공');
    } catch (e) {
      print('성찰 보고서 반려 오류: $e');
      throw Exception('성찰 보고서 반려 중 오류가 발생했습니다: $e');
    }
  }

  // 성찰 보고서 승인 메서드
  Future<void> approveReflection(String reflectionId) async {
    _validateId(reflectionId, '성찰 보고서 승인');

    try {
      print('Service - 성찰 승인 시작: 문서 ID=$reflectionId');

      await _reflectionsRef.doc(reflectionId).update(
          {'status': 'accepted', 'approvedAt': FieldValue.serverTimestamp()});

      print('Service - Firestore 승인 처리 성공');
    } catch (e) {
      print('성찰 보고서 승인 오류: $e');
      throw Exception('성찰 보고서 승인 중 오류가 발생했습니다: $e');
    }
  }

  // 학생의 성찰 보고서 가져오기
  Future<FirebaseReflectionModel?> getStudentReflection(
      String studentId, int reflectionId) async {
    if (studentId.isEmpty) {
      throw Exception('학생 ID가 비어있습니다');
    }

    try {
      QuerySnapshot querySnapshot = await _reflectionsRef
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
      throw Exception('성찰 보고서 조회 중 오류가 발생했습니다: $e');
    }
  }

  // 학생의 성찰 보고서 상태 확인
  Future<ReflectionStatus> getReflectionStatus(
      String studentId, int reflectionId) async {
    try {
      QuerySnapshot querySnapshot = await _reflectionsRef
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

      switch (status) {
        case 'submitted':
          return ReflectionStatus.submitted;
        case 'rejected':
          return ReflectionStatus.rejected;
        case 'accepted':
          return ReflectionStatus.accepted;
        default:
          return ReflectionStatus.notSubmitted;
      }
    } catch (e) {
      print('성찰 보고서 상태 조회 오류: $e');
      return ReflectionStatus.notSubmitted;
    }
  }

  // 학급의 성찰 유형별 보고서 가져오기
  Stream<List<FirebaseReflectionModel>> getClassReflections(
      String grade, int reflectionType) {
    try {
      return _reflectionsRef
          .where('grade', isEqualTo: grade)
          .where('reflectionId', isEqualTo: reflectionType)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => FirebaseReflectionModel.fromFirestore(doc))
              .toList());
    } catch (e) {
      print('성찰 보고서 목록 조회 오류: $e');
      // 오류 발생 시 빈 목록 반환
      return Stream.value([]);
    }
  }

  ///----- 통계 및 내보내기 관련 메서드 -----///

  // 학급별 제출 통계 조회
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
      QuerySnapshot reflectionsSnapshot = await _reflectionsRef
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
      // 모든 제출 데이터 가져오기
      await _reflectionsRef
          .where('grade', isEqualTo: grade)
          .where('reflectionId', isEqualTo: reflectionType)
          .get();

      // 여기서 실제로는 Cloud Functions 호출하여 Excel 생성 요청
      String reflectionTypeName = _getReflectionTypeName(reflectionType);

      // 실제 구현에서는 함수 호출 결과 반환해야 함
      return 'https://example.com/download/reflection_${grade}_${reflectionTypeName}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    } catch (e) {
      print('엑셀 생성 오류: $e');
      throw Exception('엑셀 파일 생성 중 오류가 발생했습니다: $e');
    }
  }
}
