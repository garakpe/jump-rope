// lib/screens/teacher/reflection_management.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/reflection_model.dart';
import '../../models/firebase_models.dart';
import '../../providers/task_provider.dart';

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
  String _statusMessage = ''; // 변수 선언 추가
  bool _isLoading = false; // 변수 선언 추가

  @override
  Widget build(BuildContext context) {
    if (_selectedSubmission != null) {
      return _buildSubmissionDetail();
    }

    // 학생 목록 가져오기
    final taskProvider = Provider.of<TaskProvider>(context);
    final students = taskProvider.students;
    final currentWeek = taskProvider.currentWeek;

    // 학생이 없는 경우 메시지 표시
    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '학급을 선택하고 학생을 추가해주세요',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 헤더 영역
        _buildHeaderCard(currentWeek), // 매개변수 추가
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
                    ? Colors.green.shade200
                    : Colors.orange.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _statusMessage.contains('성공')
                      ? Icons.check_circle
                      : Icons.info_outline,
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

        // 성찰 카드 그리드
        Expanded(
          child: _buildReflectionGrid(currentWeek), // 매개변수 추가
        ),
      ],
    );
  }

  // 헤더 카드 (중복 메서드 제거 및 통합)
  Widget _buildHeaderCard(int currentWeek) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

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
                  '성찰 관리',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade700,
                  ),
                ),
              ],
            ),

            // 주차 설정 UI
            Row(
              children: [
                Text(
                  '현재 주차:',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: currentWeek,
                      items: [1, 2, 3].map((week) {
                        return DropdownMenuItem<int>(
                          value: week,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              '$week주차',
                              style: TextStyle(
                                fontWeight: currentWeek == week
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _updateCurrentWeek(value);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 현재 주차 업데이트 메서드
  void _updateCurrentWeek(int newWeek) async {
    setState(() {
      _isLoading = true;
      _statusMessage = '주차 정보 업데이트 중...';
    });

    try {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      taskProvider.setCurrentWeek(newWeek);

      setState(() {
        _isLoading = false;
        _statusMessage =
            '성공: $newWeek주차로 설정되었습니다. 이제 학생들은 $newWeek주차 성찰까지 작성할 수 있습니다.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '오류: 주차 정보 업데이트 실패 - $e';
      });
    }
  }

  // 성찰 그리드 (중복 메서드 제거 및 통합)
  Widget _buildReflectionGrid(int currentWeek) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 3, // 3주차 성찰
      itemBuilder: (context, index) {
        final weekNum = index + 1;
        final bool isActive = weekNum <= currentWeek;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // 카드 헤더
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isActive
                        ? [Colors.amber.shade500, Colors.orange.shade400]
                        : [Colors.grey.shade300, Colors.grey.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$weekNum주차 성찰',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    // 활성화 상태 아이콘
                    Icon(
                      isActive ? Icons.lock_open : Icons.lock,
                      size: 16,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),

              // 학생 목록
              Expanded(
                child: isActive
                    ? _buildStudentList(weekNum)
                    : _buildInactiveWeekView(weekNum),
              ),
            ],
          ),
        );
      },
    );
  }

  // 비활성화된 주차 표시
  Widget _buildInactiveWeekView(int weekNum) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 32,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            '비활성화됨',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '현재 주차를 변경하여 활성화',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList(int weekNum) {
    final students = Provider.of<TaskProvider>(context).students;

    return ListView.builder(
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        final reflectionId =
            reflectionCards.firstWhere((r) => r.week == weekNum).id;

        // 임시로 랜덤 제출 여부 표시 (실제로는 Provider에서 확인)
        final hasSubmitted = index % 3 == 0; // 예시로 첫번째, 네번째 등의 학생만 제출한 것으로 가정

        return ListTile(
          onTap: () {
            // 제출 내용 보기 (실제로는 Provider에서 데이터 가져오기)
            final dummySubmission = ReflectionSubmission(
              studentId: student.id,
              reflectionId: reflectionId,
              week: weekNum,
              answers: {
                '이번 체육 수업에서 나의 학습 목표는 무엇인가요?':
                    '줄넘기 기술을 향상시키고 모둠 활동에 적극적으로 참여하는 것입니다.',
                '줄넘기를 잘하기 위해서 어떤 노력이 필요할까요?': '꾸준한 연습과 올바른 자세 연습이 필요합니다.',
                '나의 현재 줄넘기 실력은 어느 정도라고 생각하나요?':
                    '기본 동작은 가능하지만 어려운 기술은 더 연습이 필요합니다.',
                '모둠 활동에서 나의 역할은 무엇인가요?': '모둠원들을 격려하고 시범을 보여주는 역할입니다.',
              },
              submittedDate: DateTime.now(),
              studentName: student.name,
              className: '1',
              group: student.group,
            );

            setState(() {
              _selectedSubmission = dummySubmission;
            });
          },
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${student.group}모둠',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade800,
                fontSize: 12,
              ),
            ),
          ),
          title: Text(
            '${student.number}번 ${student.name}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: hasSubmitted ? Colors.green.shade100 : Colors.red.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              hasSubmitted ? '제출완료' : '미제출',
              style: TextStyle(
                color:
                    hasSubmitted ? Colors.green.shade800 : Colors.red.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubmissionDetail() {
    if (_selectedSubmission == null) return const SizedBox.shrink();

    final reflectionId = _selectedSubmission!.reflectionId;
    final reflection = reflectionCards.firstWhere(
      (r) => r.id == reflectionId,
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

        // 질문 및 답변 목록
        Expanded(
          child: ListView.builder(
            itemCount: reflection.questions.length,
            itemBuilder: (context, index) {
              final question = reflection.questions[index];
              final answer = _selectedSubmission!.answers[question] ?? '';

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
                      child: Text(
                        '${index + 1}. $question',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),

                    // 답변 영역
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: TextEditingController(text: answer),
                        maxLines: 4,
                        readOnly: true, // 현재는 읽기 전용
                        decoration: InputDecoration(
                          hintText: '학생 답변...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.amber.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.amber.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.amber.shade400),
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
}
