// lib/screens/student/reflection_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/firebase_models.dart';
import '../../providers/reflection_provider.dart';
import '../../providers/task_provider.dart';
import '../../models/reflection_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';

class ReflectionScreen extends StatefulWidget {
  const ReflectionScreen({Key? key}) : super(key: key);

  @override
  _ReflectionScreenState createState() => _ReflectionScreenState();
}

class _ReflectionScreenState extends State<ReflectionScreen> {
  int _selectedWeek = 1;
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    // 현재 주차 성찰 질문에 대한 컨트롤러 초기화
    final reflectionQuestions = reflectionCards
        .firstWhere((card) => card.week == _selectedWeek)
        .questions;

    for (var question in reflectionQuestions) {
      _controllers[question] = TextEditingController();
    }
  }

  @override
  void dispose() {
    // 모든 컨트롤러 해제
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final reflectionProvider = Provider.of<ReflectionProvider>(context);
    final isOffline = taskProvider.isOffline;
    final isLoading = reflectionProvider.isLoading;

    // 현재 주차 성찰 질문 가져오기
    final currentReflection = reflectionCards.firstWhere(
      (card) => card.week == _selectedWeek,
      orElse: () => reflectionCards.first,
    );

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 카드와 주차 선택기
          _buildHeaderCard(isOffline),
          const SizedBox(height: AppSpacing.md),

          // 상태 메시지
          if (_statusMessage.isNotEmpty) _buildStatusMessage(),

          // 성찰 콘텐츠
          Expanded(
            child: _buildReflectionContent(
                isLoading, currentReflection, isOffline),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(bool isOffline) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.book, color: AppColors.reflectionPrimary),
                SizedBox(width: AppSpacing.sm),
                Text(
                  '줄넘기 성찰 작성',
                  style: TextStyle(
                    fontSize: AppSizes.fontSizeLG,
                    fontWeight: FontWeight.bold,
                    color: AppColors.reflectionPrimary,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                // 오프라인 표시기
                if (isOffline) _buildOfflineIndicator(),
                // 주차 선택기
                _buildWeekSelector(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 14, color: Colors.orange.shade800),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '오프라인',
            style: TextStyle(
              fontSize: AppSizes.fontSizeXS,
              color: Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.reflectionLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButton<int>(
        value: _selectedWeek,
        dropdownColor: AppColors.white,
        underline: Container(),
        items: [1, 2, 3].map((week) {
          return DropdownMenuItem<int>(
            value: week,
            child: Text(
              '$week주차',
              style: const TextStyle(
                color: AppColors.reflectionPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedWeek = value;

              // 컨트롤러 초기화
              for (var controller in _controllers.values) {
                controller.dispose();
              }
              _controllers.clear();
              _initializeControllers();
            });
          }
        },
      ),
    );
  }

  Widget _buildStatusMessage() {
    final bool isError =
        _statusMessage.contains('오류') || _statusMessage.contains('실패');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError ? Colors.red.shade200 : Colors.green.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? Colors.red.shade700 : Colors.green.shade700,
          ),
          const SizedBox(width: AppSpacing.sm),
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
    );
  }

  Widget _buildReflectionContent(
      bool isLoading, ReflectionModel currentReflection, bool isOffline) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: isLoading || _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: ListView(
                children: [
                  Text(
                    '$_selectedWeek주차 성찰 질문',
                    style: const TextStyle(
                      fontSize: AppSizes.fontSizeLG,
                      fontWeight: FontWeight.bold,
                      color: AppColors.reflectionPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...currentReflection.questions.map((question) {
                    return _buildQuestionCard(
                      index: currentReflection.questions.indexOf(question) + 1,
                      question: question,
                    );
                  }).toList(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildSaveButton(isOffline),
                  if (isOffline)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        AppStrings.offlineMode,
                        style: TextStyle(
                          fontSize: AppSizes.fontSizeXS,
                          color: Colors.orange.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildQuestionCard({required int index, required String question}) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$index. $question',
              style: const TextStyle(
                fontSize: AppSizes.fontSizeMD,
                fontWeight: FontWeight.bold,
                color: AppColors.reflectionPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controllers[question],
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '답변을 입력해주세요...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.reflectionLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.reflectionLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.reflectionPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(bool isOffline) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.save),
        label: const Text('성찰 저장하기'),
        onPressed: _isSaving ? null : () => _saveReflection(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.reflectionPrimary,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
        ),
      ),
    );
  }

  Future<void> _saveReflection(BuildContext context) async {
    final reflectionProvider =
        Provider.of<ReflectionProvider>(context, listen: false);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userInfo;
    final isOffline = taskProvider.isOffline;

    // 모든 질문에 답변했는지 확인
    bool allAnswered = true;
    String emptyQuestions = '';

    _controllers.forEach((question, controller) {
      if (controller.text.trim().isEmpty) {
        allAnswered = false;
        if (emptyQuestions.isNotEmpty) {
          emptyQuestions += ', ';
        }
        emptyQuestions +=
            '"${question.substring(0, question.length > 20 ? 20 : question.length)}..."';
      }
    });

    if (!allAnswered) {
      setState(() {
        _statusMessage = '모든 질문에 답변해주세요: $emptyQuestions';
      });
      return;
    }

    // 현재 성찰 가져오기
    final currentReflection = reflectionCards.firstWhere(
      (card) => card.week == _selectedWeek,
    );

    // 답변 맵 준비
    final Map<String, String> answers = {};
    _controllers.forEach((question, controller) {
      answers[question] = controller.text.trim();
    });

    // 학생 정보 확인
    if (user?.studentId == null || user?.name == null) {
      setState(() {
        _statusMessage = '학생 정보를 찾을 수 없습니다. 다시 로그인해주세요.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _statusMessage = '';
    });

    try {
      // 성찰 제출 생성
      final submission = ReflectionSubmission(
        studentId: user!.studentId!,
        reflectionId: currentReflection.id,
        week: currentReflection.week,
        answers: answers,
        submittedDate: DateTime.now(),
        studentName: user.name ?? '',
        className: user.className ?? '1',
        group: int.tryParse(user.group ?? '1') ?? 1,
      );

      // 성찰 제출
      await reflectionProvider.submitReflection(submission);

      // 성공 메시지 표시
      setState(() {
        _isSaving = false;
        _statusMessage = AppStrings.reflectionComplete +
            (isOffline ? ' (${AppStrings.offlineMode})' : '');
      });

      // 오프라인 모드일 때 데이터 동기화 시도
      if (isOffline) {
        try {
          taskProvider.syncData();
        } catch (e) {
          // 동기화 오류는 무시 (이미 오프라인 경고 표시됨)
        }
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _statusMessage = '성찰 저장 중 오류가 발생했습니다: $e';
      });
    }
  }
}
