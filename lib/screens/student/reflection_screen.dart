// lib/screens/student/reflection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../models/firebase_models.dart';
import '../../providers/reflection_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../models/reflection_model.dart';

class ReflectionScreen extends StatefulWidget {
  const ReflectionScreen({Key? key}) : super(key: key);

  @override
  _ReflectionScreenState createState() => _ReflectionScreenState();
}

class _ReflectionScreenState extends State<ReflectionScreen> {
  int _selectedWeek = 1;
  bool _isSubmitting = false;
  bool _hasSubmitted = false;
  String _statusMessage = '';
  final Map<String, TextEditingController> _controllers = {};

  // 주차 활성화 상태 관리
  List<bool> _weekEnabled = [true, false, false]; // 기본값: 1주차만 활성화
  int _currentWeek = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentWeek();
      _initReflection();
    });
  }

  // 현재 주차 로드 - 간결화
  void _loadCurrentWeek() {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final currentWeek = taskProvider.currentWeek;

    setState(() {
      _currentWeek = currentWeek;
      _selectedWeek = currentWeek > _selectedWeek ? _selectedWeek : currentWeek;

      // 주차 활성화 상태 업데이트 (현재 주차까지만 활성화)
      _weekEnabled = List.generate(3, (index) => currentWeek >= index + 1);
    });
  }

  // 성찰 초기화 메서드 - 간결화
  Future<void> _initReflection() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reflectionProvider =
        Provider.of<ReflectionProvider>(context, listen: false);

    final user = authProvider.userInfo;
    if (user == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 제출 여부 확인 및 답변 가져오기
      final studentId = user.studentId ?? '';
      final reflectionId = _selectedWeek;
      final hasSubmitted =
          await reflectionProvider.hasSubmitted(studentId, reflectionId);

      if (hasSubmitted) {
        // 제출한 답변 가져오기
        final submission =
            await reflectionProvider.getSubmission(studentId, reflectionId);
        if (submission != null) {
          _initControllers(submission.answers);
        }
      } else {
        // 새 컨트롤러 초기화
        _initEmptyControllers();
      }

      setState(() {
        _hasSubmitted = hasSubmitted;
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = '데이터 로드 중 오류 발생: $e';
        _isSubmitting = false;
      });
    }
  }

  // 컨트롤러 초기화 함수
  void _initControllers(Map<String, String> answers) {
    final reflection = reflectionCards.firstWhere((r) => r.id == _selectedWeek);

    for (var question in reflection.questions) {
      final answer = answers[question] ?? '';
      if (!_controllers.containsKey(question)) {
        _controllers[question] = TextEditingController(text: answer);
      } else {
        _controllers[question]!.text = answer;
      }
    }
  }

  // 빈 컨트롤러 초기화
  void _initEmptyControllers() {
    final reflection = reflectionCards.firstWhere((r) => r.id == _selectedWeek);

    for (var question in reflection.questions) {
      if (!_controllers.containsKey(question)) {
        _controllers[question] = TextEditingController();
      } else {
        _controllers[question]!.text = '';
      }
    }
  }

  @override
  void dispose() {
    // 컨트롤러 해제
    _controllers.forEach((key, controller) {
      controller.dispose();
    });
    super.dispose();
  }

  // 주차 선택 함수
  void _selectWeek(int week) {
    if (_selectedWeek != week && _weekEnabled[week - 1]) {
      setState(() {
        _selectedWeek = week;
        _hasSubmitted = false;
        _statusMessage = '';
      });

      // 새 주차의 데이터 로드
      _initReflection();
    }
  }

  // 성찰 보고서 제출 함수
  Future<void> _submitReflection() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reflectionProvider =
        Provider.of<ReflectionProvider>(context, listen: false);

    final user = authProvider.userInfo;
    if (user == null) {
      setState(() {
        _statusMessage = '사용자 정보를 찾을 수 없습니다.';
      });
      return;
    }

    // 답변 유효성 검사
    final reflection = reflectionCards.firstWhere((r) => r.id == _selectedWeek);
    final answers = <String, String>{};
    if (!_validateAnswers(reflection.questions, answers)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = '성찰 보고서 제출 중...';
    });

    try {
      // 성찰 보고서 제출
      await reflectionProvider.submitReflection(
        ReflectionSubmission(
          studentId: user.studentId ?? '',
          reflectionId: _selectedWeek,
          week: _selectedWeek,
          answers: answers,
          submittedDate: DateTime.now(),
          studentName: user.name ?? '',
          className: user.className ?? '',
          group: int.tryParse(user.group ?? '0') ?? 0,
        ),
      );

      setState(() {
        _hasSubmitted = true;
        _isSubmitting = false;
        _statusMessage = '성찰 보고서가 성공적으로 제출되었습니다!';
      });
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _statusMessage = '제출 중 오류 발생: $e';
      });
    }
  }

  // 답변 유효성 검사
  bool _validateAnswers(List<String> questions, Map<String, String> answers) {
    bool allAnswered = true;

    for (var question in questions) {
      final answer = _controllers[question]?.text.trim() ?? '';
      if (answer.isEmpty) {
        allAnswered = false;
        break;
      }
      answers[question] = answer;
    }

    if (!allAnswered) {
      setState(() {
        _statusMessage = '모든 질문에 답변해 주세요.';
      });
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    // 현재 선택된 성찰 데이터 가져오기
    final reflection = reflectionCards.firstWhere(
      (r) => r.id == _selectedWeek,
      orElse: () => reflectionCards.first,
    );

    // 제출 버튼 활성화 여부
    final bool canSubmit = _weekEnabled[_selectedWeek - 1] && !_isSubmitting;

    return Container(
      color: CupertinoColors.systemGroupedBackground, // iOS 스타일 배경색
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // iOS 스타일 헤더
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Text(
                '성찰 일지',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5, // iOS 스타일 타이포그래피
                ),
              ),
            ),

            // iOS 스타일 세그먼트 컨트롤
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: _buildIosSegmentControl(),
            ),

            // 성찰 카드 제목
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.doc_text,
                    color: CupertinoColors.systemOrange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_selectedWeek주차 ${reflection.title}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.systemOrange.darkColor,
                    ),
                  ),
                  Expanded(child: Container()),
                  // 제출 상태 표시
                  if (_hasSubmitted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: CupertinoColors.systemGreen,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '제출 완료',
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // 상태 메시지
            if (_statusMessage.isNotEmpty) _buildStatusMessage(),

            // 질문 목록 및 답변 입력 필드
            Expanded(
              child: _isSubmitting
                  ? _buildLoadingIndicator()
                  : _buildQuestionList(reflection),
            ),

            // 제출 버튼
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: CupertinoColors.systemOrange,
                  disabledColor: CupertinoColors.systemGrey3,
                  onPressed: canSubmit ? _submitReflection : null,
                  child: Text(
                    _hasSubmitted ? '성찰 보고서 수정하기' : '성찰 보고서 제출하기',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 상태 메시지 위젯
  Widget _buildStatusMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: _statusMessage.contains('성공')
            ? CupertinoColors.systemGreen.withOpacity(0.1)
            : CupertinoColors.systemRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _statusMessage.contains('성공')
                ? CupertinoIcons.check_mark_circled
                : CupertinoIcons.exclamationmark_circle,
            color: _statusMessage.contains('성공')
                ? CupertinoColors.systemGreen
                : CupertinoColors.systemRed,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage,
              style: TextStyle(
                fontSize: 13,
                color: _statusMessage.contains('성공')
                    ? CupertinoColors.systemGreen.darkColor
                    : CupertinoColors.systemRed.darkColor,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _statusMessage = '';
              });
            },
            child: const Icon(
              CupertinoIcons.clear_circled,
              color: CupertinoColors.systemGrey,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIosSegmentControl() {
    return CupertinoSlidingSegmentedControl<int>(
      backgroundColor: CupertinoColors.systemGrey5,
      thumbColor: CupertinoColors.white,
      groupValue: _selectedWeek,
      children: {
        1: _buildSegmentItem('1주차', _selectedWeek == 1, _weekEnabled[0]),
        2: _buildSegmentItem('2주차', _selectedWeek == 2, _weekEnabled[1]),
        3: _buildSegmentItem('3주차', _selectedWeek == 3, _weekEnabled[2]),
      },
      onValueChanged: (value) {
        if (value != null && _weekEnabled[value - 1]) {
          _selectWeek(value);
        }
      },
    );
  }

  Widget _buildSegmentItem(String text, bool isSelected, bool isEnabled) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isEnabled
              ? (isSelected
                  ? CupertinoColors.systemOrange.darkColor
                  : CupertinoColors.systemGrey.darkColor)
              : CupertinoColors.systemGrey4, // 비활성화된 주차는 밝은 회색
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoActivityIndicator(radius: 16),
          SizedBox(height: 16),
          Text(
            '데이터 로드 중...',
            style: TextStyle(
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionList(ReflectionModel reflection) {
    // 비활성화된 주차인 경우
    if (!_weekEnabled[_selectedWeek - 1]) {
      return _buildDisabledWeekMessage();
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(), // iOS 스타일 스크롤 물리
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: reflection.questions.length,
      itemBuilder: (context, index) {
        final question = reflection.questions[index];

        // 답변 입력을 위한 컨트롤러가 없으면 생성
        if (!_controllers.containsKey(question)) {
          _controllers[question] = TextEditingController();
        }

        return _buildQuestionCard(index + 1, question, _controllers[question]!);
      },
    );
  }

  // 비활성화된 주차 메시지
  Widget _buildDisabledWeekMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.lock_circle,
            size: 64,
            color: CupertinoColors.systemGrey3,
          ),
          const SizedBox(height: 16),
          Text(
            '아직 $_selectedWeek주차 성찰이 활성화되지 않았습니다.',
            style: const TextStyle(
              fontSize: 16,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '현재 활성화된 주차: $_currentWeek주차',
            style: const TextStyle(
              fontSize: 14,
              color: CupertinoColors.systemGrey2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(
      int number, String question, TextEditingController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 질문 번호와 내용
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemOrange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.systemOrange,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    question,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 답변 입력 필드
            CupertinoTextField(
              controller: controller,
              maxLines: 4,
              minLines: 3,
              placeholder: '여기에 답변을 입력하세요...',
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: CupertinoColors.systemGrey4,
                ),
              ),
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
