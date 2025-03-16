import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/firebase_models.dart';
import '../../models/reflection_model.dart';
import '../../providers/reflection_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/ui/custom_reflection_card.dart'; // Import the custom card widget

class ReflectionDetailScreen extends StatefulWidget {
  final int reflectionId;
  final ReflectionSubmission? submission;
  final bool isTeacher;

  const ReflectionDetailScreen({
    Key? key,
    required this.reflectionId,
    this.submission,
    this.isTeacher = false,
  }) : super(key: key);

  @override
  State<ReflectionDetailScreen> createState() => _ReflectionDetailScreenState();
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
      // 현재 reflectionId에 해당하는 성찰 카드 가져오기
      ReflectionModel currentReflection = reflectionCards.firstWhere(
        (r) => r.id == widget.reflectionId,
        orElse: () => reflectionCards.first, // 없으면 첫 번째 카드 사용
      );

      // 제출 정보가 이미 있는 경우 그대로 사용
      if (widget.submission != null) {
        _submission = widget.submission;
        _submissionStatus = widget.submission!.status;
        _initControllers(widget.submission!.answers);
      } else {
        // 서버에서 제출 정보 로드 시도
        final studentId = user.studentId ?? '';
        final reflectionId = widget.reflectionId;

        try {
          // 성찰 상태 확인
          _submissionStatus = await reflectionProvider.getSubmissionStatus(
              studentId, reflectionId);

          // 제출 정보 로드
          _submission =
              await reflectionProvider.getSubmission(studentId, reflectionId);

          if (_submission != null) {
            _initControllers(_submission!.answers);
          } else {
            // 제출 정보가 없으면 빈 submission 생성
            _createEmptySubmission(studentId, reflectionId, currentReflection);
          }
        } catch (e) {
          print('성찰 데이터 로드 오류: $e');
          // 오류 발생 시 하드코딩된 질문 사용
          _createEmptySubmission(studentId, reflectionId, currentReflection);
        }
      }

      // 성찰 카드의 질문으로 컨트롤러 초기화 (아직 초기화되지 않은 경우)
      _initControllersFromReflectionCard(currentReflection);

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

  // 빈 제출 데이터 생성 (파이어베이스에 데이터가 없는 경우 사용)
  void _createEmptySubmission(
      String studentId, int reflectionId, ReflectionModel reflection) {
    _submission = ReflectionSubmission(
      id: 'empty_${DateTime.now().millisecondsSinceEpoch}',
      studentId: studentId,
      reflectionId: reflectionId,
      week: 0,
      answers: {},
      submittedDate: DateTime.now(),
    );
    _submissionStatus = ReflectionStatus.notSubmitted;
  }

  // 컨트롤러 초기화 (제출된 답변이 있는 경우)
  void _initControllers(Map<String, String> answers) {
    for (var entry in answers.entries) {
      final question = entry.key;
      final answer = entry.value;
      if (!_controllers.containsKey(question)) {
        _controllers[question] = TextEditingController(text: answer);
      } else {
        _controllers[question]!.text = answer;
      }
    }
  }

  // 성찰 카드의 질문으로 컨트롤러 초기화 (답변이 없는 경우)
  void _initControllersFromReflectionCard(ReflectionModel reflection) {
    for (var question in reflection.questions) {
      if (!_controllers.containsKey(question)) {
        _controllers[question] = TextEditingController();
      }
    }
  }

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
// 여기서 user.classNum이 설정되어 있는지 확인
    String classNumToUse = user.classNum ?? '';
    if (classNumToUse.isEmpty && (user.grade ?? '').isNotEmpty) {
      classNumToUse = user.grade!;
    }
    // 학번 가져오기
    String studentNumToUse = ''; // 기본값
    if ((user.studentId ?? '').length >= 2) {
      // 학번에서 뒤의 2자리를 studentNum으로 사용
      studentNumToUse = user.studentId!.substring(user.studentId!.length - 2);
    }

    // 현재 reflectionId에 해당하는 성찰 카드 가져오기
    ReflectionModel reflection = reflectionCards.firstWhere(
      (r) => r.id == widget.reflectionId,
      orElse: () => reflectionCards.first,
    );

    // 답변 유효성 검사 및 수집
    final answers = <String, String>{};
    bool allAnswered = true;
    List<String> emptyQuestions = [];

    for (var question in reflection.questions) {
      final answer = _controllers[question]?.text.trim() ?? '';
      if (answer.isEmpty || answer.length < 5) {
        allAnswered = false;
        emptyQuestions.add(question);
      } else {
        answers[question] = answer;
      }
    }

    if (!allAnswered) {
      setState(() {
        _statusMessage = '모든 질문에 충분한 답변을 작성해 주세요.';
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
          id: _submission?.id ?? '',
          studentId: user.studentId ?? '',
          reflectionId: widget.reflectionId,
          week: 0,
          answers: answers,
          submittedDate: DateTime.now(),
          studentName: user.name ?? '',
          grade: user.grade ?? '',
          classNum: classNumToUse, // 여기서 처리된 classNum 값 사용
          studentNum: studentNumToUse, // studentNum 필드 추가
          group: user.group ?? '',
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
        if (mounted) {
          Navigator.of(context).pop(true);
        }
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
    // 현재 reflectionId에 해당하는 성찰 카드 가져오기
    final reflection = reflectionCards.firstWhere(
      (r) => r.id == widget.reflectionId,
      orElse: () => reflectionCards.first, // 없으면 첫 번째 카드 사용
    );

    // 반려 사유 표시
    Widget rejectionWidget = const SizedBox.shrink();
    if (_submissionStatus == ReflectionStatus.rejected &&
        _submission != null &&
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

    // 승인 상태 표시
    Widget approvedWidget = const SizedBox.shrink();
    if (_submissionStatus == ReflectionStatus.accepted) {
      approvedWidget = Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(CupertinoIcons.checkmark_circle,
                    size: 18, color: Colors.green.shade600),
                const SizedBox(width: 8),
                Text(
                  '교사 승인됨',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '이 성찰 보고서는 교사의 승인을 받았습니다. 더 이상 수정할 수 없습니다.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.green.shade800,
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
                        '제출자: ${_submission?.studentName ?? ''}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_submissionStatus != ReflectionStatus.notSubmitted &&
                          _submission != null)
                        Text(
                          '제출일: ${DateFormat('yyyy-MM-dd HH:mm').format(_submission!.submittedDate)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),

                  // Document ID for debugging (can be removed in production)
                  if (_submission != null && _submission!.id.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'ID: ${_submission!.id}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                        ),
                      ),
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

          // 승인됨 표시 (있는 경우)
          approvedWidget,

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

            return CustomReflectionCard(
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
    final reflectionProvider =
        Provider.of<ReflectionProvider>(context, listen: false);
    final isDeadlinePassed =
        reflectionProvider.isReflectionDeadlinePassed(widget.reflectionId);

    // 교사 모드일 경우 다른 UI 표시 (기존 코드 유지)
    if (widget.isTeacher) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: CupertinoColors.systemBlue,
                  borderRadius: BorderRadius.circular(10),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    '학생 성찰 확인 완료',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (_submissionStatus == ReflectionStatus.submitted &&
                  _submission != null &&
                  _submission!.id.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    color: CupertinoColors.systemGreen,
                    borderRadius: BorderRadius.circular(10),
                    onPressed: _approveReflection,
                    child: const Text(
                      '승인',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ),
              if (_submissionStatus == ReflectionStatus.submitted &&
                  _submission != null &&
                  _submission!.id.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    color: CupertinoColors.systemOrange,
                    borderRadius: BorderRadius.circular(10),
                    onPressed: _showRejectDialog,
                    child: const Text(
                      '반려',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // 승인된 경우 제출 버튼 숨김 (기존 코드 유지)
    if (_submissionStatus == ReflectionStatus.accepted) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
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
                CupertinoIcons.checkmark_circle,
                color: CupertinoColors.systemGreen,
              ),
              SizedBox(width: 8),
              Text(
                '승인된 성찰 보고서는 수정할 수 없습니다.',
                style: TextStyle(
                  color: CupertinoColors.systemGreen,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 마감된 경우 접수 마감 메시지 표시
    if (isDeadlinePassed) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
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
                CupertinoIcons.clock,
                color: CupertinoColors.systemRed,
              ),
              SizedBox(width: 8),
              Text(
                '접수가 마감되어 읽기만 가능합니다.',
                style: TextStyle(
                  color: CupertinoColors.systemRed,
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
          color: CupertinoColors.systemBackground,
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: _getSubmitButtonColor(),
                borderRadius: BorderRadius.circular(10),
                onPressed: _isLoading ? null : _submitReflection,
                child: Text(
                  _getSubmitButtonLabel(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
    final reflectionProvider =
        Provider.of<ReflectionProvider>(context, listen: false);
    final isDeadlinePassed =
        reflectionProvider.isReflectionDeadlinePassed(widget.reflectionId);

    // 마감된 경우 버튼 색상 회색으로 변경
    if (isDeadlinePassed) {
      return Colors.grey;
    }
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
    final reflectionProvider =
        Provider.of<ReflectionProvider>(context, listen: false);
    final isDeadlinePassed =
        reflectionProvider.isReflectionDeadlinePassed(widget.reflectionId);

    // 마감된 경우 버튼 텍스트 변경
    if (isDeadlinePassed) {
      return '접수 마감됨 (읽기 전용)';
    }
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

  // 성찰 승인 메서드
  Future<void> _approveReflection() async {
    if (_submission == null) return;

    // Check if ID is empty
    if (_submission!.id.isEmpty) {
      setState(() {
        _statusMessage = '성찰 보고서 ID가 없어 승인할 수 없습니다.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '성찰 보고서 승인 중...';
    });

    try {
      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);

      // 디버깅용 로그 추가
      print('승인 시도 - 문서 ID: ${_submission!.id}');

      // 승인 처리
      await reflectionProvider.approveReflection(_submission!.id);

      setState(() {
        _isLoading = false;
        _submissionStatus = ReflectionStatus.accepted;
        _statusMessage = '성찰 보고서가 승인되었습니다.';
      });

      // 잠시 후 이전 화면으로 이동
      if (mounted) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        });
      }
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

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('성찰 보고서 반려'),
        content: Column(
          children: [
            const SizedBox(height: 16),
            const Text('반려 사유를 입력해주세요:'),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: reasonController,
              placeholder: '반려 사유를 입력하세요...',
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CupertinoColors.systemGrey4),
              ),
              maxLines: 3,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            isDefaultAction: true,
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              _rejectReflection(reasonController.text);
            },
            isDestructiveAction: true,
            child: const Text('반려하기'),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectReflection(String reason) async {
    if (_submission == null || reason.trim().isEmpty) return;

    // Check if ID is empty
    if (_submission!.id.isEmpty) {
      setState(() {
        _statusMessage = '성찰 보고서 ID가 없어 반려할 수 없습니다.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '성찰 보고서 반려 중...';
    });

    try {
      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);

      // 디버깅용 로그 추가
      print('반려 시도 - 문서 ID: ${_submission!.id}, 사유: $reason');

      // 반려 처리
      await reflectionProvider.rejectReflection(_submission!.id, reason);

      setState(() {
        _isLoading = false;
        _submissionStatus = ReflectionStatus.rejected;
        _statusMessage = '성찰 보고서가 반려되었습니다.';
      });

      // 잠시 후 이전 화면으로 이동
      if (mounted) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '반려 중 오류 발생: $e';
      });
    }
  }

// 읽기 전용 상태 계산 로직 수정
  bool _isReadOnly() {
    final reflectionProvider =
        Provider.of<ReflectionProvider>(context, listen: false);
    final isDeadlinePassed =
        reflectionProvider.isReflectionDeadlinePassed(widget.reflectionId);

    // 교사 모드이거나 승인된 성찰이거나 마감된 성찰은 읽기 전용
    return widget.isTeacher ||
        _submissionStatus == ReflectionStatus.accepted ||
        isDeadlinePassed;
  }
}
