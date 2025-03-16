// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/firebase_models.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'task_provider.dart';
import 'package:provider/provider.dart';
import '../main.dart'; // navigatorKey 사용

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  // 상태 변수
  UserModel? _currentUser;
  FirebaseUserModel? _firebaseUser;
  FirebaseStudentModel? _firebaseStudent;
  bool _isLoading = false;
  String _error = '';

  // Getters
  bool get isLoggedIn => _currentUser != null;
  bool get isTeacher => _currentUser?.isTeacher ?? false;
  UserModel? get userInfo => _currentUser;
  bool get isLoading => _isLoading;
  String get error => _error;

  // 생성자
  AuthProvider() {
    _setupAuthStateListener();
    restoreSession(); // 앱 시작 시 자동 로그인 시도
  }

  // Firebase Authentication 상태 변경 감지
  void _setupAuthStateListener() {
    try {
      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (user == null && _currentUser != null) {
          // 로그아웃 상태
          logout();
        }
      });
    } catch (e) {
      print('Auth state 리스너 설정 실패: $e');
      _setError('인증 상태 모니터링 실패: $e');
    }
  }

  // 저장된 로그인 정보 복원
  Future<void> restoreSession() async {
    _setLoading(true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userType = prefs.getString('userType');

      if (userType == 'teacher') {
        await _restoreTeacherSession(prefs);
      } else if (userType == 'student') {
        await _restoreStudentSession(prefs);
      }
    } catch (e) {
      print('세션 복원 실패: $e');
    } finally {
      _setLoading(false);
    }
  }

  // 교사 세션 복원
  Future<void> _restoreTeacherSession(SharedPreferences prefs) async {
    final String? email = prefs.getString('email');
    final String? password = prefs.getString('password');

    if (email != null &&
        email.isNotEmpty &&
        password != null &&
        password.isNotEmpty) {
      try {
        await teacherLogin(email, password);
      } catch (e) {
        print('교사 자동 로그인 실패: $e');
      }
    }
  }

  // 학생 세션 복원
  Future<void> _restoreStudentSession(SharedPreferences prefs) async {
    final String? studentId = prefs.getString('studentId');
    final String? name = prefs.getString('name');

    if (studentId != null && name != null) {
      try {
        await studentLogin(studentId, name);
      } catch (e) {
        print('학생 자동 로그인 실패: $e');
      }
    }
  }

  // 교사 로그인
  Future<void> teacherLogin(String email, String password) async {
    _setLoading(true);
    _setError('');

    try {
      _firebaseUser = await _authService.teacherLogin(email, password);

      _currentUser = UserModel(
        name: _firebaseUser!.name,
        studentId: _firebaseUser!.uid,
        isTeacher: true,
      );

      // 로그인 정보 저장
      await _saveTeacherLoginInfo(email, password);

      // TaskProvider에 사용자 변경 알림 (교사 로그인)
      _notifyTaskProviderForUserChange(null, null);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // 로그인 정보 저장 (교사)
  Future<void> _saveTeacherLoginInfo(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userType', 'teacher');
    await prefs.setString('email', email);
    await prefs.setString('password', password); // 실제 앱에서는 보안상 비밀번호 저장은 권장하지 않음
  }

  // 학생 로그인
  Future<void> studentLogin(String studentId, String name) async {
    _setLoading(true);
    _setError('');

    try {
      _firebaseStudent = await _authService.studentLogin(studentId, name);

      // 학생 사용자 모델 생성
      _currentUser = UserModel(
        name: _firebaseStudent!.name,
        studentId: _firebaseStudent!.studentId,
        grade: _firebaseStudent!.grade,
        classNum: _firebaseStudent!.classNum.isNotEmpty
            ? _firebaseStudent!.classNum
            : _firebaseStudent!.grade, // classNum 우선, 없으면 grade 사용
        group: _firebaseStudent!.group.toString(),
        isTeacher: false,
      );

      // 로그인 정보 저장
      await _saveStudentLoginInfo(studentId, name);

      // TaskProvider에 사용자 변경 알림 (학생 로그인)
      int? groupId = int.tryParse(_firebaseStudent!.group.toString());
      _notifyTaskProviderForUserChange(studentId, groupId);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // 로그인 정보 저장 (학생)
  Future<void> _saveStudentLoginInfo(String studentId, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userType', 'student');
    await prefs.setString('studentId', studentId);
    await prefs.setString('name', name);
  }

  // TaskProvider에 사용자 변경 알림
  void _notifyTaskProviderForUserChange(String? studentId, int? groupId) {
    try {
      // navigatorKey를 통해 context 가져오기
      final context = navigatorKey.currentContext;
      if (context != null) {
        // TaskProvider에 접근하여 사용자 변경 알림
        final taskProvider = Provider.of<TaskProvider>(context, listen: false);
        taskProvider.handleUserChanged(studentId, groupId);
        print('TaskProvider에 사용자 변경 알림 성공: 학생ID=$studentId, 그룹=$groupId');
      }
    } catch (e) {
      print('TaskProvider 알림 실패: $e');
      _setError('TaskProvider 알림 실패: $e');
    }
  }

  // 일반 로그인 메서드 - 직접 UserModel로 로그인 (테스트용)
  void login(UserModel user) {
    _currentUser = user;
    _saveLoginInfo(user);
    notifyListeners();
  }

  // 로그인 정보 저장
  Future<void> _saveLoginInfo(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();

    if (user.isTeacher) {
      await prefs.setString('userType', 'teacher');
      await prefs.setString('email', user.name ?? ''); // 교사의 경우 이름을 이메일로 사용
    } else {
      await prefs.setString('userType', 'student');
      await prefs.setString('studentId', user.studentId ?? '');
      await prefs.setString('name', user.name ?? '');
      await prefs.setString('grade', user.grade ?? '');
      await prefs.setString('group', user.group ?? '');
    }
  }

  // 로그아웃
  Future<void> logout() async {
    try {
      await _authService.signOut();

      // 로컬 저장된 로그인 정보 삭제
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // TaskProvider에 로그아웃 알림
      _notifyTaskProviderForUserChange(null, null);

      _currentUser = null;
      _firebaseUser = null;
      _firebaseStudent = null;
      notifyListeners();
    } catch (e) {
      print('로그아웃 실패: $e');
      _setError(e.toString());
    }
  }

  // 로딩 상태 설정
  void _setLoading(bool isLoading) {
    _isLoading = isLoading;
    notifyListeners();
  }

  // 에러 메시지 설정
  void _setError(String errorMessage) {
    _error = errorMessage;
    notifyListeners();
  }
}
