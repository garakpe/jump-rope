// lib/screens/student/reflection_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/firebase_models.dart'; // ReflectionStatus와 ReflectionSubmission 임포트
import '../../models/reflection_model.dart';
import '../../providers/reflection_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/ui/custom_reflection_card.dart'; // ReflectionEditableAnswerCard 위젯 임포트

class ReflectionDetailScreen extends StatefulWidget {
  final int reflectionId;
  final ReflectionSubmission? submission;
  final bool isTeacher; // 교사 모드 플래그 추가

  const ReflectionDetailScreen({
    Key? key,
    required this.reflectionId,
    this.submission,
    this.isTeacher = false, // 기본값은 false (학생 모드)
  }) : super(key: key);

  @override
  _ReflectionDetailScreenState createState() => _ReflectionDetailScreenState();
}

class _ReflectionDetailScreenState extends State<ReflectionDetailScreen> {
  bool _isLoading = false;
  String _statusMessage = '';
  ReflectionSubmission? _submission;
  ReflectionStatus _submissionStatus = ReflectionStatus.notSubmitted;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReflectionData();
    });
  }

  @override
  void dispose() {
    // 컨트롤러 해제
    _controllers.forEach((key, controller) {
      controller.dispose();
    });
    super.dispose();
  }

  // 성찰 데이터 로드
  Future<void> _loadReflectionData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reflectionProvider =
        Provider.of<ReflectionProvider>(context, listen: false);

    final user = authProvider.userInfo;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      // 제출 정보가 이미 있는 경우 그대로 사용
      if (widget.submission != null) {
        _submission = widget.submission;
        _submissionStatus = widget.submission!.status;
        _initControllers(widget.submission!.answers);
      } else {
        // 서버에서 제출 정보 로드
        final studentId = user.studentId ?? '';
        final reflectionId = widget.reflectionId;

        // 성찰 상태 확인
        _submissionStatus = await reflectionProvider.getSubmissionStatus(
            studentId, reflectionId);

        // 제출 정보 로드
        _submission =
            await reflectionProvider.getSubmission(studentId, reflectionId);

        if (_submission != null) {
          _initControllers(_submission!.answers);
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '데이터 로드 중 오류 발생: $e';
      });
    }
  }

  // 컨트롤러 초기화
  void _initControllers(Map<String, String> answers) {
    final reflection = reflectionCards.firstWhere(
      (r) => r.id == widget.reflectionId,
      orElse: () => reflectionCards.first,
    );

    for (var question in reflection.questions) {
      final answer = answers[question] ?? '';
      if (!_controllers.containsKey(question)) {
        _controllers[question] = TextEditingController(text: answer);
      } else {
        _controllers[question]!.text = answer;
      }
    }
  }

  // 성찰 보고서 수정 제출
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
    final reflection = reflectionCards.firstWhere(
      (r) => r.id == widget.reflectionId,
      orElse: () => reflectionCards.first,
    );

    // 답변 수집
    final answers = <String, String>{};
    bool allAnswered = true;
    List<String> emptyQuestions = [];

    for (var question in reflection.questions) {
      final answer = _controllers[question]?.text.trim() ?? '';

      // 답변이 비어있거나 너무 짧은 경우
      if (answer.isEmpty || answer.length < 5) {
        allAnswered = false;
        emptyQuestions.add(question);
      } else {
        answers[question] = answer;
      }
    }

    if (!allAnswered) {
      setState(() {
        if (emptyQuestions.isNotEmpty) {
          _statusMessage = '모든 질문에 충분한 답변을 작성해 주세요.';
        } else {
          _statusMessage = '답변은 5자 이상 작성해 주세요.';
        }
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '성찰 보고서 제출 중...';
    });

    try {
      // 성찰 보고서 제출
      await reflectionProvider.submitReflection(
        ReflectionSubmission(
          studentId: user.studentId ?? '',
          reflectionId: widget.reflectionId,
          week: reflection.week,
          answers: answers,
          submittedDate: DateTime.now(),
          studentName: user.name ?? '',
          className: user.className ?? '',
          group: int.tryParse(user.group ?? '0') ?? 0,
          status: ReflectionStatus.submitted,
        ),
      );

      setState(() {
        _isLoading = false;
        _submissionStatus = ReflectionStatus.submitted;
        _statusMessage = '성찰 보고서가 성공적으로 제출되었습니다!';
      });

      // 잠시 후 이전 화면으로 이동
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.of(context).pop(true); // 업데이트 성공 표시
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '제출 중 오류 발생: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.reflectionId}주차 성찰 보고서'),
        actions: [
          // 뒤로가기 버튼
          TextButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: const Text('돌아가기'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingIndicator() : _buildReflectionDetail(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('데이터를 불러오는 중입니다...'),
        ],
      ),
    );
  }

  Widget _buildReflectionDetail() {
    if (_submission == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.orange.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              '성찰 데이터를 찾을 수 없습니다',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '뒤로 가서 다시 시도해주세요',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    final reflection = reflectionCards.firstWhere(
      (r) => r.id == widget.reflectionId,
      orElse: () => reflectionCards.first,
    );

    // 반려 사유 표시
    Widget rejectionWidget = const SizedBox.shrink();
    if (_submissionStatus == ReflectionStatus.rejected &&
        _submission!.rejectionReason != null &&
        _submission!.rejectionReason!.isNotEmpty) {
      rejectionWidget = Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(CupertinoIcons.exclamationmark_triangle,
                    size: 18, color: Colors.red.shade600),
                const SizedBox(width: 8),
                Text(
                  '교사 반려 사유',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _submission!.rejectionReason!,
              style: TextStyle(
                fontSize: 15,
                color: Colors.red.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '위 사유를 참고하여 수정 후 다시 제출해주세요.',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 카드
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목
                  Row(
                    children: [
                      Icon(
                        Icons.book,
                        color: Colors.amber.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.reflectionId}주차 ${reflection.title}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade700,
                        ),
                      ),
                      Expanded(child: Container()),

                      // 상태 뱃지
                      _buildStatusBadge(),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 제출 정보
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '제출자: ${_submission!.studentName}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_submissionStatus != ReflectionStatus.notSubmitted)
                        Text(
                          '제출일: ${DateFormat('yyyy-MM-dd HH:mm').format(_submission!.submittedDate)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 상태 메시지
          if (_statusMessage.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _statusMessage.contains('성공')
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _statusMessage.contains('성공')
                      ? Colors.green.shade300
                      : Colors.orange.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _statusMessage.contains('성공')
                        ? Icons.check_circle
                        : Icons.warning,
                    color: _statusMessage.contains('성공')
                        ? Colors.green.shade600
                        : Colors.orange.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_statusMessage),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      setState(() {
                        _statusMessage = '';
                      });
                    },
                  ),
                ],
              ),
            ),

          // 반려 사유 (있는 경우)
          rejectionWidget,

          // 질문 및 답변 리스트
          ...List.generate(reflection.questions.length, (index) {
            final question = reflection.questions[index];

            // 컨트롤러가 없는 경우 생성
            if (!_controllers.containsKey(question)) {
              _controllers[question] = TextEditingController();
            }

            // 읽기 전용 여부 결정
            bool readOnly = _isReadOnly();

            return ReflectionEditableAnswerCard(
              index: index,
              question: question,
              controller: _controllers[question]!,
              readOnly: readOnly,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    // 교사 모드일 경우 다른 UI 표시
    if (widget.isTeacher) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  color: Colors.blue,
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('학생 성찰 확인 완료'),
                ),
              ),
              if (_submissionStatus == ReflectionStatus.submitted)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: CupertinoButton(
                    color: Colors.green,
                    onPressed: _approveReflection,
                    child: const Text('승인'),
                  ),
                ),
              if (_submissionStatus == ReflectionStatus.submitted)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: CupertinoButton(
                    color: Colors.orange,
                    onPressed: _showRejectDialog,
                    child: const Text('반려'),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // 기존 학생 모드 UI (승인된 경우 제출 버튼 숨김)
    if (_submissionStatus == ReflectionStatus.accepted) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
              ),
              SizedBox(width: 8),
              Text(
                '승인된 성찰 보고서는 수정할 수 없습니다.',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: CupertinoButton(
                color: _getSubmitButtonColor(),
                onPressed: _isLoading ? null : _submitReflection,
                child: Text(_getSubmitButtonLabel()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 성찰 승인 메서드
  Future<void> _approveReflection() async {
    if (_submission == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = '성찰 보고서 승인 중...';
    });

    try {
      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);

      // 승인 처리
      await reflectionProvider.approveReflection(_submission!.id);

      setState(() {
        _isLoading = false;
        _submissionStatus = ReflectionStatus.accepted;
        _statusMessage = '성찰 보고서가 승인되었습니다.';
      });

      // 잠시 후 이전 화면으로 이동
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.of(context).pop(true);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '승인 중 오류 발생: $e';
      });
    }
  }

  // 반려 다이얼로그 표시 메서드
  void _showRejectDialog() {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('성찰 보고서 반려'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('반려 사유를 입력해주세요:'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '반려 사유를 입력하세요...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectReflection(reasonController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('반려하기'),
          ),
        ],
      ),
    );
  }

  // 반려 처리 메서드
  Future<void> _rejectReflection(String reason) async {
    if (_submission == null || reason.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = '성찰 보고서 반려 중...';
    });

    try {
      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);

      // 반려 처리
      await reflectionProvider.rejectReflection(_submission!.id, reason);

      setState(() {
        _isLoading = false;
        _submissionStatus = ReflectionStatus.rejected;
        _statusMessage = '성찰 보고서가 반려되었습니다.';
      });

      // 잠시 후 이전 화면으로 이동
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.of(context).pop(true);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '반려 중 오류 발생: $e';
      });
    }
  }

  // 상태 뱃지 위젯
  Widget _buildStatusBadge() {
    Color backgroundColor;
    Color textColor;
    String statusText;
    IconData statusIcon;

    switch (_submissionStatus) {
      case ReflectionStatus.submitted:
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade700;
        statusText = '검토 중';
        statusIcon = Icons.pending;
        break;
      case ReflectionStatus.rejected:
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade700;
        statusText = '반려됨';
        statusIcon = Icons.cancel;
        break;
      case ReflectionStatus.accepted:
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade700;
        statusText = '승인됨';
        statusIcon = Icons.check_circle;
        break;
      case ReflectionStatus.notSubmitted:
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        statusText = '미제출';
        statusIcon = Icons.new_releases;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            size: 16,
            color: textColor,
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 제출 버튼 색상
  Color _getSubmitButtonColor() {
    switch (_submissionStatus) {
      case ReflectionStatus.rejected:
        return Colors.red;
      case ReflectionStatus.submitted:
        return Colors.blue;
      case ReflectionStatus.notSubmitted:
      default:
        return Colors.green;
    }
  }

  // 제출 버튼 텍스트
  String _getSubmitButtonLabel() {
    switch (_submissionStatus) {
      case ReflectionStatus.rejected:
        return '반려된 성찰 보고서 수정하기';
      case ReflectionStatus.submitted:
        return '성찰 보고서 수정하기';
      case ReflectionStatus.notSubmitted:
      default:
        return '성찰 보고서 제출하기';
    }
  }

  // 읽기 전용 상태 계산 로직
  bool _isReadOnly() {
    // 교사 모드이거나 승인된 성찰은 읽기 전용
    return widget.isTeacher || _submissionStatus == ReflectionStatus.accepted;
  }
}
