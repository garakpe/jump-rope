// lib/services/student_service.dart
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'dart:async';
import '../models/firebase_models.dart';

class StudentService {
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 로컬 구현을 위한 더미 데이터
  final Map<String, List<FirebaseStudentModel>> _studentsByClass = {
    '1': [
      FirebaseStudentModel(
        id: '101',
        name: '김철수',
        studentId: '12345',
        grade: '1',
        group: 1,
        individualTasks: {
          '양발모아 뛰기': {
            'completed': true,
            'completedDate': '2023-09-10 10:00:00'
          },
          '구보로 뛰기': {'completed': false, 'completedDate': null},
        },
        groupTasks: {},
      ),
      FirebaseStudentModel(
        id: '102',
        name: '홍길동',
        studentId: '67890',
        grade: '1',
        group: 2,
        individualTasks: {
          '양발모아 뛰기': {
            'completed': true,
            'completedDate': '2023-09-11 11:00:00'
          },
        },
        groupTasks: {},
      ),
      FirebaseStudentModel(
        id: '103',
        name: '이영희',
        studentId: '54321',
        grade: '1',
        group: 3,
        individualTasks: {},
        groupTasks: {},
      ),
    ],
    '2': [
      FirebaseStudentModel(
        id: '201',
        name: '박지민',
        studentId: '12346',
        grade: '2',
        group: 1,
        individualTasks: {},
        groupTasks: {},
      ),
      FirebaseStudentModel(
        id: '202',
        name: '최유리',
        studentId: '67891',
        grade: '2',
        group: 2,
        individualTasks: {},
        groupTasks: {},
      ),
    ],
  };

  // 학급별 학생 목록 가져오기
  Stream<List<FirebaseStudentModel>> getStudentsByClass(String grade) {
    try {
      // 파이어베이스 연동 코드 (주석 처리)
      // return _firestore
      //     .collection('students')
      //     .where('grade', isEqualTo: grade)
      //     .snapshots()
      //     .map((snapshot) => snapshot.docs
      //         .map((doc) => FirebaseStudentModel.fromFirestore(doc))
      //         .toList());

      // 로컬 구현
      return Stream.value(_studentsByClass[grade] ?? []);
    } catch (e) {
      print('학생 목록 조회 오류: $e');
      // 오류 발생 시 빈 목록 반환
      return Stream.value([]);
    }
  }

  // 엑셀 템플릿 URL (임시 구현)
  Future<String> createStudentTemplateExcel() async {
    // 실제 구현은 Firebase Storage 등 이용
    // 현재는 개발용 임시 URL 반환
    await Future.delayed(const Duration(seconds: 1)); // 임시 지연
    return 'https://example.com/templates/student_template.xlsx';
  }

  // 엑셀 파일 처리 및 학생 추가 (임시 구현)
  Future<int> processStudentExcel(Uint8List bytes) async {
    try {
      // 실제 구현 시 엑셀 파일 파싱 및 Firebase에 학생 추가
      // 현재는 성공 메시지만 반환
      await Future.delayed(const Duration(seconds: 2)); // 임시 지연

      // 임시 성공 메시지 (10명 추가 가정)
      return 10;
    } catch (e) {
      print('엑셀 업로드 오류: $e');
      throw Exception("엑셀 파일 처리 중 오류가 발생했습니다: $e");
    }
  }

  // 학생 정보 업데이트
  Future<void> updateStudent(FirebaseStudentModel student) async {
    try {
      // 파이어베이스 연동 코드 (주석 처리)
      // await _firestore
      //     .collection('students')
      //     .doc(student.id)
      //     .update(student.toMap());

      // 로컬 구현
      final classStudents = _studentsByClass[student.grade] ?? [];
      final index = classStudents.indexWhere((s) => s.id == student.id);

      if (index >= 0) {
        classStudents[index] = student;
      } else {
        classStudents.add(student);
      }

      _studentsByClass[student.grade] = classStudents;
    } catch (e) {
      print('학생 정보 업데이트 오류: $e');
    }
  }

  // 개발용: 샘플 학생 데이터 생성
  Future<void> createSampleStudents(String grade, int count) async {
    try {
      // 파이어베이스 연동 코드 (주석 처리)
      // WriteBatch batch = _firestore.batch();
      //
      // for (int i = 1; i <= count; i++) {
      //   final studentId =
      //       '${grade}${i.toString().padLeft(2, '0')}'; // 예: 101, 102, ...
      //   final groupNum = ((i - 1) % 4) + 1; // 1, 2, 3, 4 모둠 반복
      //
      //   DocumentReference docRef =
      //       _firestore.collection('students').doc(studentId);
      //   batch.set(docRef, {
      //     'name': '학생$i',
      //     'studentId': studentId,
      //     'grade': grade,
      //     'group': groupNum,
      //     'number': i,
      //     'individualTasks': {},
      //     'groupTasks': {},
      //     'attendance': true,
      //   });
      // }
      //
      // await batch.commit();

      // 로컬 구현
      final students = <FirebaseStudentModel>[];

      for (int i = 1; i <= count; i++) {
        final studentId =
            '$grade${i.toString().padLeft(2, '0')}'; // 예: 101, 102, ...
        final groupNum = ((i - 1) % 4) + 1; // 1, 2, 3, 4 모둠 반복

        students.add(FirebaseStudentModel(
          id: studentId,
          name: '학생$i',
          studentId: studentId,
          grade: grade,
          group: groupNum,
          individualTasks: {},
          groupTasks: {},
          attendance: true,
        ));
      }

      _studentsByClass[grade] = students;
    } catch (e) {
      print('샘플 학생 데이터 생성 오류: $e');
    }
  }
}
