// lib/screens/student/reflection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../models/firebase_models.dart';
import '../../providers/reflection_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../models/reflection_model.dart';
import './reflection_detail_screen.dart';

class ReflectionScreen extends StatefulWidget {
  const ReflectionScreen({Key? key}) : super(key: key);

  @override
  _ReflectionScreenState createState() => _ReflectionScreenState();
}

class _ReflectionScreenState extends State<ReflectionScreen> {
  String _statusMessage = '';
  bool _isLoading = false;

  // 성찰 유형 활성화 상태 관리
  List<bool> _reflectionTypeEnabled = [true, false, false]; // 기본값: 초기 성찰만 활성화
  final int _lastMask = 0; // 마지막으로 처리한 마스크 값

  @override
  void initState() {
    super.initState();
    _loadActiveReflectionTypes();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 의존성이 변경될 때마다 활성화 상태 확인
    _loadActiveReflectionTypes();
  }

// 활성화된 성찰 유형 로드 메서드 수정
  void _loadActiveReflectionTypes() {
    final reflectionProvider =
        Provider.of<ReflectionProvider>(context, listen: false);

    setState(() {
      // 각 성찰 유형별 활성화 여부 확인
      _reflectionTypeEnabled = [
        reflectionProvider.isReflectionTypeActive(1), // 초기 성찰
        reflectionProvider.isReflectionTypeActive(2), // 중기 성찰
        reflectionProvider.isReflectionTypeActive(3), // 최종 성찰
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    // Provider 변경을 감지하기 위해 Consumer 사용
    return Consumer<ReflectionProvider>(
      builder: (context, reflectionProvider, child) {
        // 빌드 시 각 성찰 유형별 활성화 여부 다시 확인
        _reflectionTypeEnabled = [
          reflectionProvider.isReflectionTypeActive(1), // 초기 성찰
          reflectionProvider.isReflectionTypeActive(2), // 중기 성찰
          reflectionProvider.isReflectionTypeActive(3), // 최종 성찰
        ];

        return CupertinoPageScaffold(
          // 기존 코드 그대로 유지
          backgroundColor: CupertinoColors.systemGroupedBackground,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // iOS 스타일 헤더
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '성찰 일지',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '체육 수업에 대한 성찰을 작성하고 제출하세요',
                        style: TextStyle(
                          fontSize: 15,
                          color: CupertinoColors.systemGrey,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // 상태 메시지
                if (_statusMessage.isNotEmpty) _buildStatusMessage(),

                // 로딩 표시
                if (_isLoading)
                  const Center(child: CupertinoActivityIndicator(radius: 16)),

                // 성찰 카드 목록
                Expanded(
                  child: _buildReflectionCards(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 상태 메시지 위젯
  Widget _buildStatusMessage() {
    final isSuccess =
        _statusMessage.contains('성공') || _statusMessage.contains('완료');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isSuccess
            ? CupertinoColors.systemGreen.withOpacity(0.1)
            : CupertinoColors.systemOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess
                ? CupertinoIcons.check_mark_circled
                : CupertinoIcons.exclamationmark_circle,
            color: isSuccess
                ? CupertinoColors.systemGreen
                : CupertinoColors.systemOrange,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage,
              style: TextStyle(
                fontSize: 14,
                color: isSuccess
                    ? CupertinoColors.systemGreen.darkColor
                    : CupertinoColors.systemOrange.darkColor,
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

  // 성찰 카드 목록 위젯
  Widget _buildReflectionCards() {
    final authProvider = Provider.of<AuthProvider>(context);
    final reflectionProvider = Provider.of<ReflectionProvider>(context);
    final user = authProvider.userInfo;

    if (user == null) {
      return const Center(
        child: Text('사용자 정보를 로드할 수 없습니다.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reflectionCards.length,
      itemBuilder: (context, index) {
        final reflection = reflectionCards[index];
        final reflectionType = reflection.id; // 성찰 유형 ID
        final isEnabled = _reflectionTypeEnabled[reflectionType - 1];

        return FutureBuilder<ReflectionStatus>(
          future: reflectionProvider.getSubmissionStatus(
              user.studentId ?? '', reflection.id),
          builder: (context, snapshot) {
            // 기본값은 미제출 상태로 설정
            final status = snapshot.data ?? ReflectionStatus.notSubmitted;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildReflectionCard(
                reflection: reflection,
                status: status,
                isEnabled: isEnabled,
                studentId: user.studentId ?? '',
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReflectionCard({
    required ReflectionModel reflection,
    required ReflectionStatus status,
    required bool isEnabled,
    required String studentId,
  }) {
    // 마감 상태 확인 추가
    final reflectionProvider = Provider.of<ReflectionProvider>(context);
    final isDeadlinePassed =
        reflectionProvider.isReflectionDeadlinePassed(reflection.id);

    // 상태에 따른 디자인 변수 설정
    final (cardColor, statusText, statusColor, statusIcon) =
        _getStatusDesign(status);

    return GestureDetector(
      onTap: isEnabled
          ? () => _navigateToReflectionDetail(reflection, status, studentId)
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 카드 헤더
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.15),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.doc_text,
                            color: cardColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            reflection.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: cardColor,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isEnabled
                              ? statusColor.withOpacity(0.1)
                              : CupertinoColors.systemGrey4,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isEnabled ? statusIcon : CupertinoIcons.lock,
                              size: 14,
                              color: isEnabled
                                  ? statusColor
                                  : CupertinoColors.systemGrey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isEnabled ? statusText : '비활성화',
                              style: TextStyle(
                                fontSize: 12,
                                color: isEnabled
                                    ? statusColor
                                    : CupertinoColors.systemGrey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // 마감 정보 표시 추가
                  if (isDeadlinePassed)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: CupertinoColors.systemRed.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.clock,
                            size: 14,
                            color: CupertinoColors.systemRed,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '접수 마감됨',
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemRed,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // 카드 내용
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reflection.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '총 ${reflection.questions.length}개의 질문',
                    style: TextStyle(
                      color: CupertinoColors.systemGrey.darkColor,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 질문 미리보기
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: CupertinoColors.systemGrey5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '질문 미리보기',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: CupertinoColors.systemGrey.darkColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getQuestionPreview(reflection.questions),
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 버튼 - 마감된 경우 상태에 따라 버튼 표시 변경
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: isEnabled
                          ? (isDeadlinePassed &&
                                  status == ReflectionStatus.notSubmitted
                              ? CupertinoColors.systemGrey3
                              : cardColor)
                          : CupertinoColors.systemGrey4,
                      borderRadius: BorderRadius.circular(12),
                      onPressed: isEnabled
                          ? (isDeadlinePassed &&
                                  status == ReflectionStatus.notSubmitted
                              ? null // 마감됐고 미제출 상태면 비활성화
                              : () => _navigateToReflectionDetail(
                                  reflection, status, studentId))
                          : null,
                      child: Text(
                        _getButtonText(status, isEnabled, isDeadlinePassed),
                        style: TextStyle(
                          color: isEnabled
                              ? (isDeadlinePassed &&
                                      status == ReflectionStatus.notSubmitted
                                  ? CupertinoColors.systemGrey
                                  : CupertinoColors.white)
                              : CupertinoColors.systemGrey,
                          fontWeight: FontWeight.w600,
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
    );
  }

  // 상태에 따른 디자인 변수 반환 함수
  (Color, String, Color, IconData) _getStatusDesign(ReflectionStatus status) {
    switch (status) {
      case ReflectionStatus.notSubmitted:
        return (
          CupertinoColors.systemBlue,
          '미제출',
          CupertinoColors.systemBlue,
          CupertinoIcons.doc_text
        );
      case ReflectionStatus.submitted:
        return (
          CupertinoColors.systemOrange,
          '제출완료',
          CupertinoColors.systemOrange,
          CupertinoIcons.checkmark_circle
        );
      case ReflectionStatus.rejected:
        return (
          CupertinoColors.systemRed,
          '반려됨',
          CupertinoColors.systemRed,
          CupertinoIcons.xmark_circle
        );
      case ReflectionStatus.accepted:
        return (
          CupertinoColors.systemGreen,
          '승인됨',
          CupertinoColors.systemGreen,
          CupertinoIcons.checkmark_seal
        );
    }
  }

// 버튼 텍스트 반환 함수 수정 - 마감 상태 고려
  String _getButtonText(
      ReflectionStatus status, bool isEnabled, bool isDeadlinePassed) {
    if (!isEnabled) return '현재 비활성화됨';

    // 마감된 경우 미제출 상태는 "마감됨" 표시
    if (isDeadlinePassed && status == ReflectionStatus.notSubmitted) {
      return '마감됨';
    }

    switch (status) {
      case ReflectionStatus.notSubmitted:
        return '성찰 작성하기';
      case ReflectionStatus.submitted:
        return isDeadlinePassed ? '제출한 성찰 보기' : '제출한 성찰 보기/수정';
      case ReflectionStatus.rejected:
        return isDeadlinePassed ? '반려된 성찰 보기' : '반려된 성찰 수정하기';
      case ReflectionStatus.accepted:
        return '승인된 성찰 보기';
    }
  }

  // 질문 미리보기 텍스트 생성 함수
  String _getQuestionPreview(List<String> questions) {
    if (questions.isEmpty) return '질문이 없습니다.';
    return questions.first +
        (questions.length > 1 ? ' 외 ${questions.length - 1}개의 질문' : '');
  }

  // _navigateToReflectionDetail 메서드
  void _navigateToReflectionDetail(ReflectionModel reflection,
      ReflectionStatus status, String studentId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);

      // 제출 정보 가져오기
      ReflectionSubmission? submission;
      try {
        submission =
            await reflectionProvider.getSubmission(studentId, reflection.id);
      } catch (e) {
        print('성찰 데이터 조회 실패: $e - 빈 양식으로 진행합니다.');
        // 오류 발생 시 null 유지 (detail 화면에서 빈 양식 생성)
      }

      if (!mounted) return;

      final result = await Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => ReflectionDetailScreen(
            reflectionId: reflection.id,
            submission: submission,
          ),
        ),
      );

      // 결과 처리
      if (result == true) {
        setState(() {
          _statusMessage = '성찰 보고서가 성공적으로 저장되었습니다!';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '오류가 발생했습니다: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
