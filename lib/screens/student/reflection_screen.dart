// lib/screens/student/reflection_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/firebase_models.dart';
import '../../providers/reflection_provider.dart';
import '../../providers/task_provider.dart';
import '../../models/reflection_model.dart';
import '../../providers/auth_provider.dart';

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
    // Initialize controllers for all questions of the current reflection
    final reflectionQuestions = reflectionCards
        .firstWhere((card) => card.week == _selectedWeek)
        .questions;

    for (var question in reflectionQuestions) {
      _controllers[question] = TextEditingController();
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    _controllers.forEach((key, controller) {
      controller.dispose();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final reflectionProvider = Provider.of<ReflectionProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userInfo;
    final isOffline = taskProvider.isOffline;
    final isLoading = reflectionProvider.isLoading;

    // Get current reflection questions
    final currentReflection = reflectionCards.firstWhere(
      (card) => card.week == _selectedWeek,
      orElse: () => reflectionCards.first,
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card with week selector
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.book, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Text(
                        '줄넘기 성찰 작성',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Offline indicator
                      if (isOffline)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cloud_off,
                                  size: 14, color: Colors.orange.shade800),
                              const SizedBox(width: 4),
                              Text(
                                '오프라인',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Week selector
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: DropdownButton<int>(
                          value: _selectedWeek,
                          dropdownColor: Colors.white,
                          underline: Container(),
                          items: [1, 2, 3].map((week) {
                            return DropdownMenuItem<int>(
                              value: week,
                              child: Text(
                                '$week주차',
                                style: TextStyle(
                                  color: Colors.amber.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedWeek = value;

                                // Clear and reinitialize controllers
                                _controllers.forEach((key, controller) {
                                  controller.dispose();
                                });
                                _controllers.clear();
                                _initializeControllers();
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Status message
          if (_statusMessage.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _statusMessage.contains('오류') ||
                        _statusMessage.contains('실패')
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _statusMessage.contains('오류') ||
                          _statusMessage.contains('실패')
                      ? Colors.red.shade200
                      : Colors.green.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _statusMessage.contains('오류') ||
                            _statusMessage.contains('실패')
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    color: _statusMessage.contains('오류') ||
                            _statusMessage.contains('실패')
                        ? Colors.red.shade700
                        : Colors.green.shade700,
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

          // Reflection content
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: isLoading || _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ListView(
                        children: [
                          Text(
                            '$_selectedWeek주차 성찰 질문',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...currentReflection.questions.map((question) {
                            return _buildQuestionCard(
                              index: currentReflection.questions
                                      .indexOf(question) +
                                  1,
                              question: question,
                            );
                          }).toList(),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.save),
                              label: const Text('성찰 저장하기'),
                              onPressed: _isSaving
                                  ? null
                                  : () => _saveReflection(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade400,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                disabledForegroundColor: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          if (isOffline)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                '오프라인 모드: 저장 내용은 네트워크 연결 시 자동으로 동기화됩니다.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard({required int index, required String question}) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$index. $question',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade700,
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
                  borderSide: BorderSide(color: Colors.amber.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.amber.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.amber.shade400),
                ),
              ),
            ),
          ],
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

    // Check if all questions are answered
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

    // Get current reflection
    final currentReflection = reflectionCards.firstWhere(
      (card) => card.week == _selectedWeek,
    );

    // Prepare answers map
    final Map<String, String> answers = {};
    _controllers.forEach((question, controller) {
      answers[question] = controller.text.trim();
    });

    // Check if student info is available
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
      // Create reflection submission
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

      // Submit reflection
      await reflectionProvider.submitReflection(submission);

      // Show success message
      setState(() {
        _isSaving = false;
        _statusMessage =
            '성찰이 성공적으로 저장되었습니다.${isOffline ? ' (오프라인 모드: 네트워크 연결 시 동기화됩니다)' : ''}';
      });

      // Try to sync data if we're in offline mode
      if (isOffline) {
        try {
          taskProvider.syncData();
        } catch (e) {
          // Ignore sync errors, we already showed offline warning
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
