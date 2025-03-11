import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/ui/custom_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _studentIdController = TextEditingController();
  final _studentNameController = TextEditingController();
  final _teacherEmailController = TextEditingController();
  final _teacherPasswordController = TextEditingController();

  String _error = '';
  bool _isStudentLogin = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _studentIdController.dispose();
    _studentNameController.dispose();
    _teacherEmailController.dispose();
    _teacherPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleStudentLogin() async {
    if (_studentIdController.text.isEmpty ||
        _studentNameController.text.isEmpty) {
      setState(() {
        _error = '학번과 이름을 모두 입력해주세요.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // AuthProvider를 통해 학생 로그인 시도
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.studentLogin(
        _studentIdController.text,
        _studentNameController.text,
      );

      // 로그인 실패 시 (에러가 발생하면 catch 블록으로 이동)
      if (authProvider.error.isNotEmpty) {
        setState(() {
          _error = authProvider.error;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleTeacherLogin() async {
    if (_teacherEmailController.text.isEmpty ||
        _teacherPasswordController.text.isEmpty) {
      setState(() {
        _error = '이메일과 비밀번호를 모두 입력해주세요.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // AuthProvider를 통해 교사 로그인 시도
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.teacherLogin(
        _teacherEmailController.text,
        _teacherPasswordController.text,
      );

      // 로그인 실패 시 (에러가 발생하면 catch 블록으로 이동)
      if (authProvider.error.isNotEmpty) {
        setState(() {
          _error = authProvider.error;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 현재 로그인 상태 확인
    final authProvider = Provider.of<AuthProvider>(context);
    final isLoading = authProvider.isLoading || _isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 상단 헤더 영역
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue, Color(0xFF3E7BFA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '줄넘기 학습 관리',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // iOS 스타일 세그먼트 컨트롤
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.shade700.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _isStudentLogin = true;
                                    _error = '';
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _isStudentLogin
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '학생 로그인',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _isStudentLogin
                                            ? Colors.blue
                                            : Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _isStudentLogin = false;
                                    _error = '';
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !_isStudentLogin
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '교사 로그인',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: !_isStudentLogin
                                            ? Colors.blue
                                            : Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 로그인 폼 영역
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: _isStudentLogin
                        ? _buildStudentForm()
                        : _buildTeacherForm(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentForm() {
    return Column(
      children: [
        // 학번 입력 필드
        TextField(
          controller: _studentIdController,
          decoration: const InputDecoration(
            labelText: '학번',
            prefixIcon: Icon(Icons.school),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          keyboardType: TextInputType.number,
          enabled: !_isLoading,
        ),
        const SizedBox(height: 16),

        // 이름 입력 필드
        TextField(
          controller: _studentNameController,
          decoration: const InputDecoration(
            labelText: '이름',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          enabled: !_isLoading,
        ),

        // 에러 메시지 영역
        if (_error.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 24),

        // 로그인 버튼
        _isLoading
            ? const CircularProgressIndicator()
            : CustomButton(
                label: '로그인',
                onPressed: _handleStudentLogin,
                width: double.infinity,
                height: 50,
                borderRadius: 16,
                backgroundColor: Colors.blue,
              ),

        // 로그인 안내
        const SizedBox(height: 16),
        const Text(
          '학번과 이름을 입력하여 로그인하세요',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTeacherForm() {
    return Column(
      children: [
        // 이메일 입력 필드
        TextField(
          controller: _teacherEmailController,
          decoration: const InputDecoration(
            labelText: '이메일',
            prefixIcon: Icon(Icons.email),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          keyboardType: TextInputType.emailAddress,
          enabled: !_isLoading,
        ),
        const SizedBox(height: 16),

        // 비밀번호 입력 필드
        TextField(
          controller: _teacherPasswordController,
          decoration: const InputDecoration(
            labelText: '비밀번호',
            prefixIcon: Icon(Icons.lock),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          obscureText: true,
          enabled: !_isLoading,
        ),

        // 에러 메시지 영역
        if (_error.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 24),

        // 로그인 버튼
        _isLoading
            ? const CircularProgressIndicator()
            : CustomButton(
                label: '로그인',
                onPressed: _handleTeacherLogin,
                width: double.infinity,
                height: 50,
                borderRadius: 16,
                backgroundColor: Colors.blue,
              ),

        // 테스트 계정 안내
        const SizedBox(height: 16),
        const Text(
          '교사 로그인을 위해 등록된 이메일과 비밀번호를 입력하세요',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }
}
