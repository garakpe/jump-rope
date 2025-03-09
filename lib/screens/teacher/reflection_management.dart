// lib/screens/teacher/reflection_management.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/reflection_model.dart';
import '../../models/firebase_models.dart';
import '../../providers/task_provider.dart';
import '../../providers/reflection_provider.dart';

class ReflectionManagement extends StatefulWidget {
  final int selectedClassId;

  const ReflectionManagement({
    Key? key,
    required this.selectedClassId,
  }) : super(key: key);

  @override
  _ReflectionManagementState createState() => _ReflectionManagementState();
}

class _ReflectionManagementState extends State<ReflectionManagement> {
  ReflectionSubmission? _selectedSubmission;
  int _selectedWeek = 1;
  bool _isLoading = false;
  String _errorMessage = '';
  List<FirebaseReflectionModel> _submissions = [];

  @override
  void initState() {
    super.initState();
    _loadReflectionData();
  }

  @override
  void didUpdateWidget(ReflectionManagement oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 학급이 변경되면 데이터 다시 로드
    if (oldWidget.selectedClassId != widget.selectedClassId) {
      _loadReflectionData();
    }
  }

  // 성찰 데이터 로드
  Future<void> _loadReflectionData() async {
    if (widget.selectedClassId <= 0) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);

      // 주차별 성찰 데이터 로드
      reflectionProvider.selectClassAndWeek(
          widget.selectedClassId.toString(), _selectedWeek);

      print('성찰 데이터 로드 요청: ${widget.selectedClassId}반, $_selectedWeek주차');
    } catch (e) {
      setState(() {
        _errorMessage = '성찰 데이터 로드 중 오류가 발생했습니다: $e';
      });
      print('성찰 데이터 로드 오류: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 선택된 제출물이 있으면 상세보기 표시
    if (_selectedSubmission != null) {
      return _buildSubmissionDetail();
    }

    // 성찰 데이터 상태 관리
    final reflectionProvider = Provider.of<ReflectionProvider>(context);
    _submissions = reflectionProvider.submissions;
    final isProviderLoading = reflectionProvider.isLoading;
    final providerError = reflectionProvider.error;

    // 로딩 상태 동기화
    if (_isLoading != isProviderLoading) {
      _isLoading = isProviderLoading;
    }

    // 오류 메시지 동기화
    if (providerError.isNotEmpty && _errorMessage.isEmpty) {
      _errorMessage = providerError;
    }

    // 학생 목록 가져오기
    final taskProvider = Provider.of<TaskProvider>(context);
    final students = taskProvider.students;

    return Column(
      children: [
        // 헤더 영역
        _buildHeaderCard(),
        const SizedBox(height: 16),

        // 오류 메시지 표시
        if (_errorMessage.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_errorMessage),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    setState(() {
                      _errorMessage = '';
                    });
                  },
                ),
              ],
            ),
          ),

        // 본문 내용 - Column의 children 안에서 if-else 문법 수정
        if (_isLoading)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('성찰 데이터를 불러오는 중...'),
                ],
              ),
            ),
          )
        else if (students.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.book_outlined,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    '학급을 선택하고 학생을 추가해주세요',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('다시 시도'),
                    onPressed: _loadReflectionData,
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: _buildReflectionGrid(),
          ),
      ],
    );
  }

  Widget _buildHeaderCard() {
    return Card(
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
                  '${widget.selectedClassId}반 성찰 관리',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade700,
                  ),
                ),
              ],
            ),
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
                    });

                    // 주차 변경 시 데이터 새로 로드
                    final reflectionProvider =
                        Provider.of<ReflectionProvider>(context, listen: false);
                    reflectionProvider.selectClassAndWeek(
                        widget.selectedClassId.toString(), value);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReflectionGrid() {
    final taskProvider = Provider.of<TaskProvider>(context);
    final students = taskProvider.students;

    // 성찰 데이터가 없는 경우 메시지 표시
    if (_submissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined,
                size: 64, color: Colors.amber.shade200),
            const SizedBox(height: 16),
            Text(
              '제출된 성찰 보고서가 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '학생들이 $_selectedWeek주차 성찰 보고서를 제출하면 여기에 표시됩니다',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // 학생 ID를 성찰 데이터와 매핑하기 위한 맵 생성
    final submissionMap = <String, FirebaseReflectionModel>{};
    for (var submission in _submissions) {
      submissionMap[submission.studentId] = submission;
    }

    // 학급의 학생별로 성찰 보고서 목록 표시
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        final studentId = student.id;
        final hasSubmitted = submissionMap.containsKey(studentId);

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 카드 헤더
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: hasSubmitted
                      ? Colors.green.shade100
                      : Colors.grey.shade100,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        student.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: hasSubmitted
                              ? Colors.green.shade800
                              : Colors.grey.shade800,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: hasSubmitted
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        hasSubmitted ? '제출완료' : '미제출',
                        style: TextStyle(
                          color: hasSubmitted
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 학생 정보
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '학번: ${student.studentId}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.groups_outlined,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${student.group}모둠',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),

                    // 제출 정보
                    if (hasSubmitted) ...[
                      const SizedBox(height: 8),
                      const Divider(),
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16, color: Colors.green.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '제출일: ${_formatDate(submissionMap[studentId]!.submittedDate)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const Spacer(),

              // 버튼 영역
              Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                  onPressed: hasSubmitted
                      ? () => _showSubmissionDetail(submissionMap[studentId]!)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasSubmitted
                        ? Colors.amber.shade400
                        : Colors.grey.shade300,
                    foregroundColor:
                        hasSubmitted ? Colors.white : Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        hasSubmitted ? Icons.visibility : Icons.visibility_off,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text('성찰 보기'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSubmissionDetail(FirebaseReflectionModel reflection) {
    // FirebaseReflectionModel을 ReflectionSubmission으로 변환
    final submission = ReflectionSubmission(
      studentId: reflection.studentId,
      reflectionId: reflection.week, // 임시로 week를 ID로 사용
      week: reflection.week,
      answers: reflection.answers,
      submittedDate: reflection.submittedDate,
      studentName: reflection.studentName,
      className: reflection.className,
      group: reflection.group,
    );

    setState(() {
      _selectedSubmission = submission;
    });
  }

  Widget _buildSubmissionDetail() {
    if (_selectedSubmission == null) return const SizedBox.shrink();

    final reflectionId = _selectedSubmission!.reflectionId;
    final reflection = reflectionCards.firstWhere(
      (r) => r.id == reflectionId || r.week == _selectedSubmission!.week,
      orElse: () => reflectionCards.first,
    );

    return Column(
      children: [
        // 헤더 영역
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
                      '${_selectedSubmission!.studentName}의 ${reflection.week}주차 성찰',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('돌아가기'),
                  onPressed: () {
                    setState(() {
                      _selectedSubmission = null;
                    });
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.amber.shade50,
                    foregroundColor: Colors.amber.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 학생 정보 카드
        Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.person,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedSubmission!.studentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_selectedSubmission!.className}학년 ${widget.selectedClassId}반 ${_selectedSubmission!.group}모둠',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '제출일',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _formatDate(_selectedSubmission!.submittedDate),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 질문 및 답변 목록
        Expanded(
          child: ListView.builder(
            itemCount: reflection.questions.length,
            itemBuilder: (context, index) {
              final question = reflection.questions[index];
              final answer =
                  _selectedSubmission!.answers[question] ?? '(답변 없음)';

              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 질문 헤더
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              question,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 답변 영역
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          answer,
                          style: const TextStyle(
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 날짜 포맷팅 함수
  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}
