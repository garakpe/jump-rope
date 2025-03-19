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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 로고 및 학교명
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.groups_rounded,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '가락고등학교',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '줄넘기 학습 관리',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 로그인 카드
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 16,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // 상단 세그먼트 컨트롤
                        Container(
                          padding: const EdgeInsets.all(16),
                          color:
                              const Color(0xFFEFF6FF), // light blue background
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E7EB), // gray background
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                // 학생 로그인 탭
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
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: _isStudentLogin
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.05),
                                                  blurRadius: 4,
                                                  spreadRadius: 0,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Text(
                                        '학생 로그인',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: _isStudentLogin
                                              ? Colors.blue
                                              : Colors.grey[600],
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // 교사 로그인 탭
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
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: !_isStudentLogin
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.05),
                                                  blurRadius: 4,
                                                  spreadRadius: 0,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Text(
                                        '교사 로그인',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: !_isStudentLogin
                                              ? Colors.blue
                                              : Colors.grey[600],
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 로그인 폼
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: _isStudentLogin
                              ? _buildStudentForm()
                              : _buildTeacherForm(),
                        ),
                      ],
                    ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 학번 입력 필드
        const Text(
          '학번',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            border: Border.all(color: const Color(0xFFD1D5DB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                spreadRadius: 0,
              ),
            ],
          ),
          child: TextField(
            controller: _studentIdController,
            keyboardType: TextInputType.number,
            enabled: !_isLoading,
            decoration: const InputDecoration(
              hintText: '학번을 입력하세요',
              prefixIcon: Icon(Icons.school, color: Color(0xFF9CA3AF)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 이름 입력 필드
        const Text(
          '이름',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            border: Border.all(color: const Color(0xFFD1D5DB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                spreadRadius: 0,
              ),
            ],
          ),
          child: TextField(
            controller: _studentNameController,
            enabled: !_isLoading,
            decoration: const InputDecoration(
              hintText: '이름을 입력하세요',
              prefixIcon: Icon(Icons.person, color: Color(0xFF9CA3AF)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),

        // 에러 메시지
        if (_error.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFFF87171), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 24),

        // 로그인 버튼
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _handleStudentLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 1,
                  ),
                  child: const Text(
                    '로그인',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

        // 로그인 안내
        const SizedBox(height: 16),
        const Center(
          child: Text(
            '학번과 이름을 입력하여 로그인하세요',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeacherForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 이메일 입력 필드
        const Text(
          '이메일',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            border: Border.all(color: const Color(0xFFD1D5DB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                spreadRadius: 0,
              ),
            ],
          ),
          child: TextField(
            controller: _teacherEmailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_isLoading,
            decoration: const InputDecoration(
              hintText: '이메일을 입력하세요',
              prefixIcon: Icon(Icons.email, color: Color(0xFF9CA3AF)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 비밀번호 입력 필드
        const Text(
          '비밀번호',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            border: Border.all(color: const Color(0xFFD1D5DB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                spreadRadius: 0,
              ),
            ],
          ),
          child: TextField(
            controller: _teacherPasswordController,
            obscureText: true,
            enabled: !_isLoading,
            decoration: const InputDecoration(
              hintText: '비밀번호를 입력하세요',
              prefixIcon: Icon(Icons.lock, color: Color(0xFF9CA3AF)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),

        // 에러 메시지
        if (_error.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFFF87171), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 24),

        // 로그인 버튼
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _handleTeacherLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 1,
                  ),
                  child: const Text(
                    '로그인',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

        // 로그인 안내
        const SizedBox(height: 16),
        const Center(
          child: Text(
            '교사 로그인을 위해 등록된 이메일과 비밀번호를 입력하세요',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
