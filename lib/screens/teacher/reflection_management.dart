// lib/screens/teacher/reflection_management.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/reflection_model.dart';
import '../../models/firebase_models.dart';
import '../../providers/task_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/reflection_provider.dart';
import '../student/reflection_detail_screen.dart';

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
  String _statusMessage = '';
  bool _isLoading = false;
  int _selectedWeek = 1; // 현재 선택된 주차 추가

  @override
  void initState() {
    super.initState();

    // 화면이 처음 로드될 때 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.selectedClassId > 0) {
        // 선택된 학급에 대한 성찰 데이터 로드
        final reflectionProvider =
            Provider.of<ReflectionProvider>(context, listen: false);
        reflectionProvider.selectClassAndWeek(
            widget.selectedClassId.toString(), 1); // 1주차부터 시작

        print('성찰 관리 - 선택된 학급: ${widget.selectedClassId}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedSubmission != null) {
      return _buildSubmissionDetail();
    }

    // 학생 목록 가져오기
    final taskProvider = Provider.of<TaskProvider>(context);
    final currentWeek = taskProvider.currentWeek;

    return Column(
      children: [
        // 헤더 영역
        _buildHeaderCard(currentWeek),
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
          child: _buildReflectionGrid(currentWeek),
        ),
      ],
    );
  }

  // 헤더 카드
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

      // 주차 변경 시 선택된 주차도 변경
      _selectedWeek = newWeek;

      // 리스트 업데이트를 위해 ReflectionProvider 업데이트
      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);
      reflectionProvider.selectClassAndWeek(
          widget.selectedClassId.toString(), newWeek);

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

  // 학생 성찰 보고서 보기 메서드
  Future<void> _viewStudentReflection(
      FirebaseStudentModel student, int reflectionId) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);

      // 학생 성찰 데이터 가져오기 (로컬이나 서버에서)
      final submission = await reflectionProvider.getSubmission(
          student.studentId, reflectionId);

      setState(() {
        _isLoading = false;
      });

      if (submission != null) {
        // ReflectionDetailScreen으로 이동하여 성찰 보고서 보기
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReflectionDetailScreen(
              reflectionId: reflectionId,
              submission: submission,
              isTeacher: true, // 교사 모드로 설정
            ),
          ),
        );

        // 결과가 true이면 상태 업데이트
        if (result == true) {
          reflectionProvider.selectClassAndWeek(
              widget.selectedClassId.toString(), _selectedWeek);
          setState(() {
            _statusMessage = '${student.name}의 성찰 보고서를 확인했습니다.';
          });
        }
      } else {
        setState(() {
          _statusMessage = '${student.name}의 성찰 보고서를 불러올 수 없습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '오류 발생: $e';
      });
    }
  }

  // 성찰 그리드
  Widget _buildReflectionGrid(int currentWeek) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
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

  // 학생 목록 이벤트 핸들러 업데이트
  Widget _buildStudentList(int weekNum) {
    final studentProvider = Provider.of<StudentProvider>(context);
    final reflectionProvider = Provider.of<ReflectionProvider>(context);

    final students = studentProvider.students;
    final reflectionId =
        reflectionCards.firstWhere((r) => r.week == weekNum).id;

    // 학생 로딩 중인 경우 로딩 표시
    if (studentProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // 학생이 없는 경우 메시지 표시
    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_alt_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '이 학급에 학생이 없습니다',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              '상단의 "학생 일괄 등록" 버튼을 클릭하여 학생을 추가하세요',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];

        // FutureBuilder를 사용하여 제출 상태 확인
        return FutureBuilder<ReflectionStatus>(
          future: reflectionProvider.getSubmissionStatus(
              student.studentId, reflectionId),
          builder: (context, snapshot) {
            // 로딩 중이거나 오류 시 기본값으로 미제출 상태 표시
            ReflectionStatus status =
                snapshot.data ?? ReflectionStatus.notSubmitted;

            // 상태에 따른 표시 정보 결정
            bool hasSubmitted = status != ReflectionStatus.notSubmitted;
            Color statusColor;
            String statusText;

            switch (status) {
              case ReflectionStatus.submitted:
                statusColor = Colors.blue.shade100;
                statusText = '제출완료';
                break;
              case ReflectionStatus.rejected:
                statusColor = Colors.orange.shade100;
                statusText = '반려됨';
                break;
              case ReflectionStatus.accepted:
                statusColor = Colors.green.shade100;
                statusText = '승인됨';
                break;
              case ReflectionStatus.notSubmitted:
              default:
                statusColor = Colors.red.shade100;
                statusText = '미제출';
                break;
            }

            return ListTile(
              onTap: () async {
                // 학생 성찰 보고서 상세 보기 구현 - 제출된 경우에만 상세 보기 가능
                if (hasSubmitted) {
                  _viewStudentReflection(student, reflectionId);
                } else {
                  // 미제출 상태일 때 메시지 표시
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('${student.name} 학생은 아직 성찰 보고서를 제출하지 않았습니다.'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
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
                student.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '학번: ${student.studentId}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: status == ReflectionStatus.submitted
                        ? Colors.blue.shade800
                        : status == ReflectionStatus.accepted
                            ? Colors.green.shade800
                            : status == ReflectionStatus.rejected
                                ? Colors.orange.shade800
                                : Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          },
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
