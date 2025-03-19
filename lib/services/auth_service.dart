// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/firebase_models.dart';

class AuthService {
  // Firebase 연동을 위한 코드
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 현재 로그인한 사용자 정보
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 현재 사용자 가져오기
  User? get currentUser => _auth.currentUser;

  // 로컬 데이터 구현을 위한 더미 데이터 (Firebase 연결 실패 시 백업용)
  final List<FirebaseUserModel> _teacherUsers = [
    FirebaseUserModel(
      uid: 'teacher1',
      name: '교사',
      email: 'teacher@example.com',
      isTeacher: true,
      teacherCode: 'T001',
    )
  ];

  final List<FirebaseStudentModel> _studentUsers = [
    FirebaseStudentModel(
      id: '101',
      name: '김철수',
      studentId: '12345',
      grade: '1',
      studentNum: '1',
      group: '1',
      individualTasks: {
        '양발모아 뛰기': {'completed': true, 'completedDate': '2023-09-10 10:00:00'},
        '구보로 뛰기': {'completed': false, 'completedDate': null},
      },
      groupTasks: {},
    ),
  ];

  // 교사 등록 (앱 초기화 때 사용할 수 있는 함수)
  Future<void> registerTeacher(
      String email, String password, String name, String teacherCode) async {
    try {
      // 1. 교사 계정 생성
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      // 2. Firestore에 교사 정보 저장
      await _firestore.collection('teachers').doc(result.user!.uid).set({
        'name': name,
        'email': email,
        'isTeacher': true,
        'teacherCode': teacherCode,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('교사 등록 오류: $e');
      // 오류 발생 시 로컬 구현 백업으로 사용 (개발용)
      rethrow;
    }
  }

  // 교사 로그인
  Future<FirebaseUserModel> teacherLogin(String email, String password) async {
    try {
      // 1. Firebase Auth 로그인
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      // 2. Firestore에서 교사 정보 확인
      DocumentSnapshot teacherDoc =
          await _firestore.collection('teachers').doc(result.user!.uid).get();

      if (!teacherDoc.exists) {
        throw Exception("교사 정보가 존재하지 않습니다");
      }

      return FirebaseUserModel.fromFirestore(teacherDoc);
    } catch (e) {
      print('교사 로그인 오류: $e');

      // Firebase 초기화 실패 또는 네트워크 오류 시 로컬 테스트 로직 사용
      if (e.toString().contains('network') ||
          e.toString().contains('Firebase')) {
        // 테스트용 계정: '교사' / 'password'
        if (password != 'password') {
          throw Exception("비밀번호가 일치하지 않습니다");
        }

        final teacher = _teacherUsers.firstWhere(
          (t) => t.email == email || t.name == email,
          orElse: () => throw Exception("교사 정보가 존재하지 않습니다"),
        );

        return teacher;
      }
      throw Exception("로그인에 실패했습니다: $e");
    }
  }

  // 학생 로그인 (학번과 이름을 사용한 간편 로그인)
  Future<FirebaseStudentModel> studentLogin(
      String studentId, String name) async {
    try {
      // Firestore에서 학생 정보 찾기
      QuerySnapshot querySnapshot = await _firestore
          .collection('students')
          .where('studentId', isEqualTo: studentId)
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        // 디버깅을 위한 로그 추가
        print('학생 정보를 찾을 수 없습니다. 학번: $studentId, 이름: $name');

        // 추가 디버깅: 학번으로만 검색해보기
        QuerySnapshot idOnlySnapshot = await _firestore
            .collection('students')
            .where('studentId', isEqualTo: studentId)
            .limit(10)
            .get();

        if (idOnlySnapshot.docs.isNotEmpty) {
          print('학번으로만 검색 시 결과 있음: ${idOnlySnapshot.docs.length}건');
          for (var doc in idOnlySnapshot.docs) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            print('찾은 학생: 학번=${data['studentId']}, 이름=${data['name']}');
          }
        } else {
          print('학번으로도 검색 결과 없음');
        }

        throw Exception("학생 정보가 존재하지 않습니다");
      }

      return FirebaseStudentModel.fromFirestore(querySnapshot.docs.first);
    } catch (e) {
      print('학생 로그인 오류: $e');

      // Firebase 초기화 실패 또는 네트워크 오류 시 로컬 테스트 로직 사용
      if (e.toString().contains('network') ||
          e.toString().contains('Firebase')) {
        // 로컬 구현
        final student = _studentUsers.firstWhere(
          (s) => s.studentId == studentId && s.name == name,
          orElse: () => throw Exception("학생 정보가 존재하지 않습니다"),
        );

        return student;
      }
      throw Exception("로그인에 실패했습니다: $e");
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('로그아웃 오류: $e');
      // Firebase 초기화 실패 시 로컬 지연만 추가
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }
}
