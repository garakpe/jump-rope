// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/firebase_models.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  FirebaseUserModel? _firebaseUser;
  FirebaseStudentModel? _firebaseStudent;
  bool _isLoading = false;
  String _error = '';

  bool get isLoggedIn => _currentUser != null;
  bool get isTeacher => _currentUser?.isTeacher ?? false;
  UserModel? get userInfo => _currentUser;
  bool get isLoading => _isLoading;
  String get error => _error;

  // 생성자에서 인증 상태 구독
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
    }
  }

  // 저장된 로그인 정보 복원
  Future<void> restoreSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userType = prefs.getString('userType');

      if (userType == 'teacher') {
        final String? email = prefs.getString('email');
        if (email != null && email.isNotEmpty) {
          final String? password = prefs.getString('password');
          if (password != null && password.isNotEmpty) {
            try {
              await teacherLogin(email, password);
            } catch (e) {
              // 자동 로그인 실패 시 무시
              print('교사 자동 로그인 실패: $e');
            }
          }
        }
      } else if (userType == 'student') {
        final String? studentId = prefs.getString('studentId');
        final String? name = prefs.getString('name');

        if (studentId != null && name != null) {
          try {
            await studentLogin(studentId, name);
          } catch (e) {
            // 자동 로그인 실패 시 무시
            print('학생 자동 로그인 실패: $e');
          }
        }
      }
    } catch (e) {
      print('세션 복원 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 교사 로그인
  Future<void> teacherLogin(String email, String password) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      _firebaseUser = await _authService.teacherLogin(email, password);

      _currentUser = UserModel(
        name: _firebaseUser!.name,
        studentId: _firebaseUser!.uid,
        isTeacher: true,
      );

      // 로그인 정보 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userType', 'teacher');
      await prefs.setString('email', email);
      await prefs.setString(
          'password', password); // 실제 앱에서는 보안상 비밀번호 저장은 권장하지 않음

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  // 학생 로그인
  Future<void> studentLogin(String studentId, String name) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      _firebaseStudent = await _authService.studentLogin(studentId, name);

      _currentUser = UserModel(
        name: _firebaseStudent!.name,
        studentId: _firebaseStudent!.studentId,
        className: _firebaseStudent!.className,
        classNum: _firebaseStudent!.classNum, // classNum 추가
        group: _firebaseStudent!.group.toString(),
        isTeacher: false,
      );

      // 로그인 정보 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userType', 'student');
      await prefs.setString('studentId', studentId);
      await prefs.setString('name', name);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  // 일반 로그인 메서드 - 직접 UserModel로 로그인 (테스트용)
  void login(UserModel user) {
    _currentUser = user;

    // 로그인 정보 저장
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
      await prefs.setString('className', user.className ?? '');
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

      _currentUser = null;
      _firebaseUser = null;
      _firebaseStudent = null;
      notifyListeners();
    } catch (e) {
      print('로그아웃 실패: $e');
      _error = e.toString();
      notifyListeners();
    }
  }
}
