// lib/services/reflection_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:excel/excel.dart';
import '../models/firebase_models.dart';
import '../models/reflection_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/material.dart';

class ReflectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 로컬 캐시 및 오프라인 지원을 위한 데이터
  final Map<String, List<FirebaseReflectionModel>> _reflectionsByClass = {};
  final Map<String, Map<int, FirebaseReflectionModel>> _studentReflections = {};
  final List<Map<String, dynamic>> _pendingUploads = [];

  ReflectionService() {
    _loadOfflineData();
    createSampleReflections(); // 샘플 데이터는 유지
  }

  // 오프라인 데이터 로드
  Future<void> _loadOfflineData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 보류 중인 업로드 로드
      final String? pendingUploadsJson =
          prefs.getString('pendingReflectionUploads');
      if (pendingUploadsJson != null) {
        final List<dynamic> pendingList = jsonDecode(pendingUploadsJson);
        _pendingUploads.clear();
        _pendingUploads.addAll(pendingList.cast<Map<String, dynamic>>());
        print('보류 중인 성찰 업로드 로드: ${_pendingUploads.length}개');
      }
    } catch (e) {
      print('오프라인 데이터 로드 오류: $e');
    }
  }

  // 보류 중인 업로드 저장
  Future<void> _savePendingUploads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encodedData = jsonEncode(_pendingUploads);
      await prefs.setString('pendingReflectionUploads', encodedData);
    } catch (e) {
      print('보류 중인 업로드 저장 오류: $e');
    }
  }

  // 네트워크 상태 확인
  Future<bool> isNetworkAvailable() async {
    try {
      // 간단한 Firestore 요청으로 연결 테스트
      await _firestore.collection('app_data').doc('status').get().timeout(
            const Duration(seconds: 3),
            onTimeout: () => throw TimeoutException('연결 시간 초과'),
          );
      return true;
    } catch (e) {
      print('네트워크 연결 확인 오류: $e');
      return false;
    }
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
    };

    // 로컬에 즉시 저장 (오프라인 대응)
    final submittedDate = DateTime.now();
    String id = 'local_${DateTime.now().millisecondsSinceEpoch}';

    try {
      if (await isNetworkAvailable()) {
        // Firebase에 저장 시도
        try {
          DocumentReference docRef = await _firestore
              .collection('reflections')
              .add(reflectionData)
              .timeout(const Duration(seconds: 5));

          id = docRef.id;
          print('성찰 보고서 Firebase에 저장 성공: $id');
        } catch (e) {
          print('Firebase 저장 오류, 로컬 저장 사용: $e');

          // 오류 발생 시 보류 중인 업로드 목록에 추가
          _pendingUploads.add({
            'data': reflectionData,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
          await _savePendingUploads();
        }
      } else {
        // 오프라인 상태면 보류 중인 업로드에 추가
        print('오프라인 상태, 로컬에만 저장');
        _pendingUploads.add({
          'data': reflectionData,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        await _savePendingUploads();
      }

      // 로컬 캐시에도 저장
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
      print('성찰 보고서 제출 중 예외 발생: $e');
      return 'error_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // 학생의 성찰 보고서 가져오기
  Future<FirebaseReflectionModel?> getStudentReflection(
      String studentId, int reflectionId) async {
    try {
      // 로컬 캐시 확인
      if (_studentReflections.containsKey(studentId) &&
          _studentReflections[studentId]!.containsKey(reflectionId)) {
        return _studentReflections[studentId]![reflectionId];
      }

      // 네트워크 확인
      if (await isNetworkAvailable()) {
        try {
          // Firebase에서 데이터 가져오기
          final QuerySnapshot querySnapshot = await _firestore
              .collection('reflections')
              .where('studentId', isEqualTo: studentId)
              .where('reflectionId', isEqualTo: reflectionId)
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 5));

          if (querySnapshot.docs.isEmpty) {
            return null;
          }

          // Firestore 결과 파싱
          final reflection =
              FirebaseReflectionModel.fromFirestore(querySnapshot.docs.first);

          // 로컬 캐시 업데이트
          if (!_studentReflections.containsKey(studentId)) {
            _studentReflections[studentId] = {};
          }
          _studentReflections[studentId]![reflectionId] = reflection;

          return reflection;
        } catch (e) {
          print('Firebase에서 성찰 가져오기 오류: $e');
          // 네트워크 오류 시 로컬 캐시 재확인
          return _studentReflections[studentId]?[reflectionId];
        }
      } else {
        // 오프라인 상태면 캐시된 데이터만 반환
        return _studentReflections[studentId]?[reflectionId];
      }
    } catch (e) {
      print('성찰 보고서 조회 오류: $e');
      return null;
    }
  }

  // 학급의 주차별 성찰 보고서 가져오기
  Stream<List<FirebaseReflectionModel>> getClassReflections(
      String className, int week) {
    // 스트림 컨트롤러 생성
    final controller = StreamController<List<FirebaseReflectionModel>>();

    // 먼저 로컬 캐시 데이터 반환 (즉시 UI 업데이트)
    Future.microtask(() {
      final cachedReflections = _reflectionsByClass[className] ?? [];
      final weekReflections =
          cachedReflections.where((r) => r.week == week).toList();
      controller.add(weekReflections);
    });

    // 네트워크 상태 확인 후 Firebase 데이터 로드
    isNetworkAvailable().then((isOnline) {
      if (isOnline) {
        // Firebase 데이터 구독
        final subscription = _firestore
            .collection('reflections')
            .where('className', isEqualTo: className)
            .where('week', isEqualTo: week)
            .snapshots()
            .listen(
          (snapshot) {
            final reflections = snapshot.docs
                .map((doc) => FirebaseReflectionModel.fromFirestore(doc))
                .toList();

            // 캐시 업데이트
            final allCachedReflections = _reflectionsByClass[className] ?? [];
            final othersWeeks =
                allCachedReflections.where((r) => r.week != week).toList();
            _reflectionsByClass[className] = [...othersWeeks, ...reflections];

            // 학생별 캐시도 업데이트
            for (var reflection in reflections) {
              if (!_studentReflections.containsKey(reflection.studentId)) {
                _studentReflections[reflection.studentId] = {};
              }
              _studentReflections[reflection.studentId]![reflection.week] =
                  reflection;
            }

            // 스트림에 데이터 추가
            controller.add(reflections);
          },
          onError: (error) {
            print('Firebase 성찰 스트림 오류: $error');
            // 오류 발생 시 로컬 데이터 유지
            controller.addError('데이터 로드 오류: $error');
          },
        );

        // 컨트롤러 종료 시 구독 취소
        controller.onCancel = () {
          subscription.cancel();
        };
      } else {
        // 오프라인 상태면 로컬 데이터만 사용
        print('오프라인 상태: 로컬 캐시 데이터만 사용');
      }
    });

    return controller.stream;
  }

  // 성찰 보고서 엑셀 다운로드 URL 생성
  Future<String> generateReflectionExcel(String className, int week) async {
    try {
      if (!await isNetworkAvailable()) {
        throw Exception("네트워크 연결이 필요합니다");
      }

      // 1. 해당 학급, 주차 성찰 데이터 가져오기
      final QuerySnapshot querySnapshot = await _firestore
          .collection('reflections')
          .where('className', isEqualTo: className)
          .where('week', isEqualTo: week)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception("해당 주차에 제출된 성찰이 없습니다");
      }

      // 2. 엑셀 파일 생성
      final excel = Excel.createExcel();
      final sheet = excel['성찰보고서_$className반_$week주차'];

      // 헤더 추가
      final headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );

      // 기본 헤더 - 학번, 이름, 반, 모둠, 제출일
      final headers = ['학번', '이름', '반', '모둠', '제출일'];

      // 질문 헤더 추가 (첫 번째 문서에서 질문 목록 가져오기)
      final firstDoc = querySnapshot.docs.first;
      final firstData = firstDoc.data() as Map<String, dynamic>;
      final questions = List<String>.from(firstData['questions'] ?? []);

      headers.addAll(questions);

      // 헤더 행 작성
      for (var i = 0; i < headers.length; i++) {
        final cell =
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      // 데이터 행 작성
      int rowIndex = 1;
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final answers = Map<String, String>.from(data['answers'] ?? {});

        // 기본 정보
        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
            .value = TextCellValue(data['studentId'] ?? '');

        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
            .value = TextCellValue(data['studentName'] ?? '');

        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
            .value = TextCellValue(data['className'] ?? '');

        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
            .value = TextCellValue(data['group'].toString());

        // 제출일 포맷팅
        String submittedDate = '';
        final timestamp = data['submittedDate'];
        if (timestamp is Timestamp) {
          final date = timestamp.toDate();
          submittedDate =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        }

        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
            .value = TextCellValue(submittedDate);

        // 질문별 답변
        for (var i = 0; i < questions.length; i++) {
          final question = questions[i];
          final answer = answers[question] ?? '';

          sheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: 5 + i, rowIndex: rowIndex))
              .value = TextCellValue(answer);
        }

        rowIndex++;
      }

      // 3. 엑셀 파일 생성
      final excelBytes = excel.encode();
      if (excelBytes == null) {
        throw Exception("엑셀 파일 생성에 실패했습니다");
      }

      // 4. Firebase Storage에 업로드
      final fileName =
          'reflections/${className}_Week${week}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final ref = _storage.ref(fileName);

      await ref.putData(
        Uint8List.fromList(excelBytes),
        SettableMetadata(
            contentType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
      );

      // 5. 다운로드 URL 생성
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('엑셀 생성 오류: $e');
      throw Exception("엑셀 파일 생성 중 오류가 발생했습니다: $e");
    }
  }

  // 오프라인 상태에서 저장된 데이터를 서버와 동기화
  Future<void> syncOfflineData() async {
    if (_pendingUploads.isEmpty) return;

    if (!await isNetworkAvailable()) {
      throw Exception("네트워크 연결이 필요합니다");
    }

    print('오프라인 데이터 동기화 시작: ${_pendingUploads.length}개');

    // 동기화할 데이터 복사
    final uploadsCopy = List<Map<String, dynamic>>.from(_pendingUploads);
    _pendingUploads.clear();
    await _savePendingUploads();

    int successCount = 0;
    final failedUploads = <Map<String, dynamic>>[];

    // 각 항목 처리
    for (var upload in uploadsCopy) {
      try {
        final reflectionData = upload['data'] as Map<String, dynamic>;

        // Firebase에 저장
        await _firestore.collection('reflections').add(reflectionData);
        successCount++;
      } catch (e) {
        print('항목 동기화 실패: $e');
        failedUploads.add(upload);
      }
    }

    // 실패한 항목 다시 추가
    if (failedUploads.isNotEmpty) {
      _pendingUploads.addAll(failedUploads);
      await _savePendingUploads();
    }

    print('동기화 완료: $successCount 성공, ${failedUploads.length} 실패');
  }

  // 성찰 질문 목록 초기화 (앱 초기화 시 사용)
  Future<void> initializeReflectionQuestions() async {
    try {
      // Firebase 연동 코드
      final questionsDoc = await _firestore
          .collection('app_data')
          .doc('reflection_questions')
          .get();

      if (!questionsDoc.exists) {
        await _firestore
            .collection('app_data')
            .doc('reflection_questions')
            .set({
          'reflections': reflectionCards
              .map((card) => {
                    'id': card.id,
                    'title': card.title,
                    'week': card.week,
                    'questions': card.questions,
                  })
              .toList(),
        });
      }
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
