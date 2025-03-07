// lib/screens/teacher/progress_management.dart 파일 전체 코드

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../models/ui_models.dart';
import 'package:intl/intl.dart';

class ProgressManagement extends StatefulWidget {
  final int selectedClassId;

  const ProgressManagement({
    Key? key,
    required this.selectedClassId,
  }) : super(key: key);

  @override
  _ProgressManagementState createState() => _ProgressManagementState();
}

class _ProgressManagementState extends State<ProgressManagement> {
  String _viewMode = 'individual'; // 'individual' 또는 'group'

  @override
  void initState() {
    super.initState();

    // 학급 선택 시 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.selectedClassId > 0) {
        final taskProvider = Provider.of<TaskProvider>(context, listen: false);
        taskProvider.selectClass(widget.selectedClassId.toString());
        print('ProgressManagement - 선택된 학급: ${widget.selectedClassId}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final students = taskProvider.students;
    final isLoading = taskProvider.isLoading;
    final isOffline = taskProvider.isOffline;

    // 디버그 정보 출력
    print(
        '학습 현황 - 선택된 학급: ${widget.selectedClassId}, 학생 수: ${students.length}');

    // 학생이 없는 경우 로딩 표시 또는 메시지 표시
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '학급을 선택하고 학생을 추가해주세요',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    // 모둠 정보 계산
    final currentGroups = <int>{};
    for (var student in students) {
      currentGroups.add(student.group);
    }

    final sortedGroups = currentGroups.toList()..sort();

    return Column(
      children: [
        // 헤더 영역
        _buildHeaderCard(),
        const SizedBox(height: 16),

        // 오프라인 모드 알림
        if (isOffline)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '오프라인 모드: 변경 사항은 네트워크 연결이 복구되면 동기화됩니다',
                    style: TextStyle(color: Colors.orange.shade700),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    taskProvider.syncData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('데이터 동기화 중...')),
                    );
                  },
                  child: Text(
                    '동기화',
                    style: TextStyle(color: Colors.orange.shade700),
                  ),
                ),
              ],
            ),
          ),

        // 모둠별 진도 현황
        Expanded(
          child: _buildProgressTable(students),
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
                Icon(
                  Icons.school,
                  color: _viewMode == 'individual'
                      ? Colors.blue.shade700
                      : Colors.green.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.selectedClassId}반 학습 현황',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _viewMode == 'individual'
                        ? Colors.blue.shade700
                        : Colors.green.shade700,
                  ),
                ),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.green.shade400],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              padding: const EdgeInsets.all(2),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _viewMode = 'individual';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _viewMode == 'individual'
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        '개인줄넘기',
                        style: TextStyle(
                          color: _viewMode == 'individual'
                              ? Colors.blue.shade700
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _viewMode = 'group';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _viewMode == 'group'
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        '단체줄넘기',
                        style: TextStyle(
                          color: _viewMode == 'group'
                              ? Colors.green.shade700
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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

  Widget _buildProgressTable(List<StudentProgress> students) {
    final tasks = _viewMode == 'individual' ? individualTasks : groupTasks;

    // 모둠별로 학생 그룹화
    final Map<int, List<StudentProgress>> groupedStudents = {};
    for (var student in students) {
      if (!groupedStudents.containsKey(student.group)) {
        groupedStudents[student.group] = [];
      }
      groupedStudents[student.group]!.add(student);
    }

    // 모둠 번호 정렬
    final sortedGroups = groupedStudents.keys.toList()..sort();

    return SingleChildScrollView(
      child: Column(
        children: sortedGroups.map((groupNum) {
          final groupStudents = groupedStudents[groupNum]!;
          // 각 모둠 내에서 학생 이름 기준으로 정렬
          groupStudents.sort((a, b) => a.name.compareTo(b.name));

          // 모둠의 단체줄넘기 자격 여부 확인
          final qualification = _checkGroupQualification(groupStudents);

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 모둠 헤더
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _viewMode == 'individual'
                        ? Colors.blue.shade100
                        : Colors.green.shade100,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$groupNum모둠 (${groupStudents.length}명)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _viewMode == 'individual'
                              ? Colors.blue.shade800
                              : Colors.green.shade800,
                        ),
                      ),
                      if (_viewMode == 'group')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: qualification.qualified
                                ? Colors.green.shade200
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            qualification.qualified
                                ? '단체줄넘기 시작 가능!'
                                : '개인 성공 ${qualification.count}/${qualification.needed}',
                            style: TextStyle(
                              color: qualification.qualified
                                  ? Colors.green.shade900
                                  : Colors.grey.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 진도표
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columnSpacing: 10,
                      headingRowColor: WidgetStateProperty.all(
                        _viewMode == 'individual'
                            ? Colors.blue.shade50
                            : Colors.green.shade50,
                      ),
                      dataRowColor: WidgetStateProperty.all(Colors.white),
                      border: TableBorder.all(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                      columns: [
                        const DataColumn(
                          label: Text('모둠원',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const DataColumn(
                          label: Center(
                            child: Text('출석',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        ...tasks.map((task) => DataColumn(
                              label: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      task.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      task.count,
                                      style: const TextStyle(fontSize: 11),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )),
                      ],
                      rows: groupStudents.map((student) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${student.number}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    student.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Center(
                                child: student.attendance
                                    ? Icon(Icons.check_circle,
                                        color: Colors.green.shade600)
                                    : Icon(Icons.cancel,
                                        color: Colors.red.shade400),
                              ),
                            ),
// lib/screens/teacher/progress_management.dart의 _buildProgressTable 내부에서 DataCell 부분 수정

                            ...tasks.map((task) {
                              final isIndividual = _viewMode == 'individual';
                              final progress = isIndividual
                                  ? student.individualProgress[task.name]
                                  : student.groupProgress[task.name];
                              final isCompleted =
                                  progress?.isCompleted ?? false;
                              final completionDate = progress?.completedDate;

                              return DataCell(
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      // 단체줄넘기는 자격 있을 때만 체크 가능
                                      bool canToggle = true;
                                      if (!isIndividual && !isCompleted) {
                                        // 단체줄넘기는 자격 조건 확인
                                        canToggle = qualification.qualified;
                                      }

                                      if (student.attendance && canToggle) {
                                        // 도장 부여/취소 로직 호출
                                        _toggleTaskCompletion(
                                            student.id,
                                            task.name,
                                            !isCompleted,
                                            !isIndividual);

                                        // 디버깅용
                                        print(
                                            '도장 상태 변경 시도: 학생=${student.id}, 과제=${task.name}, 완료=${!isCompleted}');
                                      } else if (!canToggle &&
                                          !isIndividual &&
                                          !isCompleted) {
                                        // 단체줄넘기 자격이 없는 경우 안내
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                '단체줄넘기는 개인줄넘기 성공 도장 ${qualification.needed}개 이상 획득 시 시작할 수 있습니다.'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      }
                                    },
                                    child: Ink(
                                      width: double.infinity,
                                      height: double.infinity,
                                      color: isCompleted
                                          ? (isIndividual
                                              ? Colors.blue.shade50
                                              : Colors.green.shade50)
                                          : null,
                                      child: Center(
                                        child: isCompleted
                                            ? Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.check_circle,
                                                    color: isIndividual
                                                        ? Colors.blue
                                                        : Colors.green,
                                                    size: 24,
                                                  ),
                                                  if (completionDate != null)
                                                    Positioned(
                                                      bottom: 0,
                                                      child: Text(
                                                        _formatDate(
                                                            completionDate),
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Colors
                                                              .grey.shade600,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              )
                                            : Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.add_circle_outline,
                                                    color: Colors.grey.shade400,
                                                    size: 20,
                                                  ),
                                                  Text(
                                                    "클릭하여 도장 부여",
                                                    style: TextStyle(
                                                      fontSize: 8,
                                                      color:
                                                          Colors.grey.shade500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // 단체줄넘기 자격 알림 (개인줄넘기 탭에서만 표시)
                if (_viewMode == 'individual' && !qualification.qualified)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                  color: Colors.blue.shade700, fontSize: 14),
                              children: [
                                const TextSpan(
                                  text: '개인줄넘기 목표: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text:
                                      '${qualification.count}/${qualification.needed} 완료',
                                ),
                                TextSpan(
                                  text:
                                      ' - 단체줄넘기 시작을 위해 ${qualification.needed - qualification.count}개가 더 필요합니다',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // 날짜 포맷팅 함수
  String _formatDate(String? dateString) {
    if (dateString == null) return '';

    try {
      final dateTime = DateTime.parse(dateString);
      return DateFormat('yy/MM/dd').format(dateTime);
    } catch (e) {
      // 날짜 형식이 아닌 경우 원본 그대로 반환
      return dateString.substring(0, min(10, dateString.length));
    }
  }

  // 날짜 문자열 길이 제한 함수
  int min(int a, int b) {
    return a < b ? a : b;
  }

// lib/screens/teacher/progress_management.dart의 _toggleTaskCompletion 메서드

  void _toggleTaskCompletion(
      String studentId, String taskName, bool completed, bool isGroupTask) {
    // TaskProvider 참조
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final isOffline = taskProvider.isOffline;

    print('도장 토글: 학생=$studentId, 과제=$taskName, 완료=$completed, 그룹=$isGroupTask');

    // 로딩 스낵바를 추적하기 위한 키 생성
    final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

    // 알림 대화상자 표시
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(completed ? '과제 성공 도장 부여' : '과제 성공 도장 취소'),
        content: Text(completed
            ? '$taskName 과제에 성공 도장을 부여하시겠습니까?'
            : '$taskName 과제의 성공 도장을 취소하시겠습니까?'),
        actions: [
          TextButton(
            child: const Text('취소'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text(completed ? '도장 부여' : '도장 취소'),
            onPressed: () async {
              Navigator.of(context).pop();

              // 로딩 표시 - 타임아웃 설정
              final snackBar = SnackBar(
                content: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 16),
                    Text('${completed ? '도장 부여' : '도장 취소'} 중...'),
                  ],
                ),
                duration: const Duration(seconds: 3), // 최대 3초 표시
                backgroundColor: Colors.blue.shade700,
              );

              // 스낵바 표시
              ScaffoldMessenger.of(context).showSnackBar(snackBar);

              try {
                // TaskProvider를 통해 상태 업데이트
                await taskProvider.updateTaskStatus(
                    studentId, taskName, completed, isGroupTask);

                // 성공 시 기존 스낵바 제거 후 성공 메시지 표시
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(completed
                        ? '$taskName 과제에 성공 도장을 부여했습니다.'
                        : '$taskName 과제의 성공 도장을 취소했습니다.'),
                    backgroundColor: completed ? Colors.green : Colors.orange,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );

                // 매우 중요: UI 강제 갱신
                setState(() {});
              } catch (e) {
                // 오류 발생 시 기존 스낵바 제거 후 오류 메시지 표시
                ScaffoldMessenger.of(context).hideCurrentSnackBar();

                // 오프라인 상태면 다른 메시지 표시
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isOffline
                        ? '오프라인 모드: 변경 사항은 로컬에 저장되었으며 네트워크 연결 시 동기화됩니다.'
                        : '오류 발생: $e'),
                    backgroundColor: isOffline ? Colors.orange : Colors.red,
                    behavior: SnackBarBehavior.floating,
                    action: isOffline
                        ? SnackBarAction(
                            label: '동기화 시도',
                            onPressed: () {
                              taskProvider.syncData();
                            },
                          )
                        : null,
                  ),
                );

                // 오류가 발생해도 UI 갱신 (로컬 상태는 업데이트되었을 수 있음)
                setState(() {});
              }
            },
          ),
        ],
      ),
    );
  }

  // 모둠별 단체줄넘기 자격 여부 확인
  QualificationStatus _checkGroupQualification(
      List<StudentProgress> groupStudents) {
    if (groupStudents.isEmpty) {
      return QualificationStatus(qualified: false, count: 0, needed: 0);
    }

    // 개인줄넘기 성공 합계
    final totalSuccesses = groupStudents.fold<int>(0, (total, student) {
      return total +
          student.individualProgress.values.where((p) => p.isCompleted).length;
    });

    // 필요한 개수: 학생 수 × 5
    final neededSuccesses = groupStudents.length * 5;

    return QualificationStatus(
      qualified: totalSuccesses >= neededSuccesses,
      count: totalSuccesses,
      needed: neededSuccesses,
    );
  }
}

class QualificationStatus {
  final bool qualified;
  final int count;
  final int needed;

  QualificationStatus({
    required this.qualified,
    required this.count,
    required this.needed,
  });
}
