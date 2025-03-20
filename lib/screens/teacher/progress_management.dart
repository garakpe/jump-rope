// lib/screens/teacher/progress_management.dart - iOS-style redesign

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
        taskProvider
            .selectClass(widget.selectedClassId.toString().padLeft(2, '0'));
        print('ProgressManagement - 선택된 학급: ${widget.selectedClassId}');
      }
    });
  }

  @override
  void didUpdateWidget(ProgressManagement oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 학급이 변경되었을 때 데이터 새로고침
    if (oldWidget.selectedClassId != widget.selectedClassId &&
        widget.selectedClassId > 0) {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      print('ProgressManagement - 학급 변경 감지: ${widget.selectedClassId}');
      taskProvider
          .selectClass(widget.selectedClassId.toString().padLeft(2, '0'));
    }
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
        child: CupertinoActivityIndicator(radius: 16),
      );
    }

    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.person_2,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '학급을 선택하고 학생을 추가해주세요',
              style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                  fontSize: 16),
            ),
          ],
        ),
      );
    }

// 모둠 정보 계산
    final currentGroups = <String>{};
    for (var student in students) {
      currentGroups.add(student.group);
    }

    final sortedGroups = currentGroups.toList()..sort();

    return Column(
      children: [
        // 헤더 영역
        _buildHeaderCard(),
        const SizedBox(height: 12),

        // 오프라인 모드 알림
        if (isOffline)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9E6), // 옅은 노란색
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.wifi_slash,
                    color: CupertinoColors.systemOrange),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '오프라인 모드: 변경 사항은 네트워크 연결이 복구되면 동기화됩니다',
                    style: TextStyle(
                      color: CupertinoColors.systemOrange,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: const Text(
                    '동기화',
                    style: TextStyle(
                      color: CupertinoColors.activeBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () {
                    taskProvider.syncData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('데이터 동기화 중...')),
                    );
                  },
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
    // iOS 스타일로 헤더 리디자인
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  _viewMode == 'individual'
                      ? CupertinoIcons.person_crop_circle
                      : CupertinoIcons.person_3_fill,
                  color: _viewMode == 'individual'
                      ? CupertinoColors.activeBlue
                      : CupertinoColors.activeGreen,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  '${widget.selectedClassId}반 학습 현황',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _viewMode == 'individual'
                        ? CupertinoColors.activeBlue
                        : CupertinoColors.activeGreen,
                  ),
                ),
              ],
            ),
            // iOS 스타일 세그먼트 컨트롤
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
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
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _viewMode == 'individual'
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 2,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        '개인줄넘기',
                        style: TextStyle(
                          color: _viewMode == 'individual'
                              ? CupertinoColors.activeBlue
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
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
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _viewMode == 'group'
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 2,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        '단체줄넘기',
                        style: TextStyle(
                          color: _viewMode == 'group'
                              ? CupertinoColors.activeGreen
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
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
    // 수정: TaskModel의 정적 메서드 사용
    final tasks = _viewMode == 'individual'
        ? TaskModel.getIndividualTasks()
        : TaskModel.getGroupTasks();

    // 모둠별로 학생 그룹화
    final Map<String, List<StudentProgress>> groupedStudents = {};
    for (var student in students) {
      if (!groupedStudents.containsKey(student.group)) {
        groupedStudents[student.group] = [];
      }
      groupedStudents[student.group]!.add(student);
    }

    // 모둠 번호 정렬
    final sortedGroups = groupedStudents.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: sortedGroups.length,
      itemBuilder: (context, index) {
        final groupNum = sortedGroups[index];
        final groupStudents = groupedStudents[groupNum]!;
        // 각 모둠 내에서 학생 이름 기준으로 정렬
        groupStudents.sort((a, b) => a.name.compareTo(b.name));

        // 모둠의 단체줄넘기 자격 여부 확인
        final qualification = _checkGroupQualification(groupStudents);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 모둠 헤더 - iOS 스타일로 리디자인
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _viewMode == 'individual'
                      ? const Color(0xFFE5F1FC) // 밝은 파란색 배경
                      : const Color(0xFFE6F7EC), // 밝은 녹색 배경
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _viewMode == 'individual'
                                ? CupertinoColors.activeBlue
                                : CupertinoColors.activeGreen,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              groupNum,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '모둠 (${groupStudents.length}명)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: _viewMode == 'individual'
                                ? CupertinoColors.activeBlue
                                : CupertinoColors.activeGreen,
                          ),
                        ),
                      ],
                    ),
                    if (_viewMode == 'group')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: qualification.qualified
                              ? const Color(0xFFE6F7EC)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: qualification.qualified
                                ? CupertinoColors.activeGreen
                                : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              qualification.qualified
                                  ? CupertinoIcons.check_mark_circled_solid
                                  : CupertinoIcons.timer,
                              color: qualification.qualified
                                  ? CupertinoColors.activeGreen
                                  : Colors.grey.shade600,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              qualification.qualified
                                  ? '단체줄넘기 가능'
                                  : '${qualification.count}/${qualification.needed}',
                              style: TextStyle(
                                color: qualification.qualified
                                    ? CupertinoColors.activeGreen
                                    : Colors.grey.shade700,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // iOS 스타일 진도표
              _buildIOSStyleProgressTable(groupStudents, tasks, qualification),

              // 단체줄넘기 자격 알림 (개인줄넘기 탭에서만 표시)
              if (_viewMode == 'individual' && !qualification.qualified)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5F1FC), // 옅은 파란색
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: CupertinoColors.systemBlue.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.info_circle_fill,
                        color: CupertinoColors.systemBlue,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: CupertinoColors.systemBlue,
                              fontSize: 14,
                              height: 1.3,
                            ),
                            children: [
                              const TextSpan(
                                text: '개인줄넘기 목표: ',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              TextSpan(
                                text:
                                    '${qualification.count}/${qualification.needed} 완료',
                              ),
                              TextSpan(
                                text:
                                    ' (${qualification.needed - qualification.count}개 더 필요)',
                                style: TextStyle(
                                  color: CupertinoColors.systemBlue
                                      .withOpacity(0.7),
                                  fontSize: 13,
                                ),
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
      },
    );
  }

  Widget _buildIOSStyleProgressTable(List<StudentProgress> students,
      List<TaskModel> tasks, QualificationStatus qualification) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더 행
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        '모둠원',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Center(
                        child: Text(
                          '출석',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ),
                    ...tasks.map((task) {
                      return SizedBox(
                        width: 90,
                        child: Center(
                          child: Column(
                            children: [
                              Text(
                                task.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  task.count,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),

              // 구분선
              Divider(color: Colors.grey.shade200, height: 1),

              // 학생 행
              ...students.map((student) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      child: Row(
                        children: [
                          // 학생 정보
                          SizedBox(
                            width: 80,
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: _viewMode == 'individual'
                                        ? CupertinoColors.systemBlue
                                            .withOpacity(0.1)
                                        : CupertinoColors.systemGreen
                                            .withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      student.studentNum,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: _viewMode == 'individual'
                                            ? CupertinoColors.systemBlue
                                            : CupertinoColors.systemGreen,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    student.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 출석 상태
                          SizedBox(
                            width: 40,
                            child: Center(
                              child: student.attendance
                                  ? const Icon(
                                      CupertinoIcons.check_mark_circled_solid,
                                      color: CupertinoColors.activeGreen,
                                      size: 22,
                                    )
                                  : const Icon(
                                      CupertinoIcons.xmark_circle_fill,
                                      color: CupertinoColors.systemRed,
                                      size: 22,
                                    ),
                            ),
                          ),

                          // 과제 완료 상태
                          ...tasks.map((task) {
                            final isIndividual = _viewMode == 'individual';
                            final progress = isIndividual
                                ? student.individualProgress[task.name]
                                : student.groupProgress[task.name];
                            final isCompleted = progress?.isCompleted ?? false;
                            final completionDate = progress?.completedDate;

                            return SizedBox(
                              width: 90,
                              height: 60,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
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
                                    } else if (!canToggle &&
                                        !isIndividual &&
                                        !isCompleted) {
                                      // 단체줄넘기 자격이 없는 경우 안내
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              '단체줄넘기는 개인줄넘기 성공 도장 ${qualification.needed}개 이상 획득 시 시작할 수 있습니다.'),
                                          backgroundColor:
                                              CupertinoColors.systemOrange,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: isCompleted
                                          ? (isIndividual
                                              ? const Color(
                                                  0xFFE5F1FC) // 옅은 파란색
                                              : const Color(
                                                  0xFFE6F7EC)) // 옅은 녹색
                                          : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isCompleted
                                            ? (isIndividual
                                                ? CupertinoColors.systemBlue
                                                    .withOpacity(0.3)
                                                : CupertinoColors.systemGreen
                                                    .withOpacity(0.3))
                                            : Colors.grey.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: isCompleted
                                          ? Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  CupertinoIcons
                                                      .checkmark_seal_fill,
                                                  color: isIndividual
                                                      ? CupertinoColors
                                                          .systemBlue
                                                      : CupertinoColors
                                                          .systemGreen,
                                                  size: 22,
                                                ),
                                                if (completionDate != null)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            top: 4),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isIndividual
                                                          ? CupertinoColors
                                                              .systemBlue
                                                              .withOpacity(0.1)
                                                          : CupertinoColors
                                                              .systemGreen
                                                              .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      _formatDate(
                                                          completionDate),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: isIndividual
                                                            ? CupertinoColors
                                                                .systemBlue
                                                            : CupertinoColors
                                                                .systemGreen,
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
                                                  CupertinoIcons.plus_circle,
                                                  color: Colors.grey.shade400,
                                                  size: 20,
                                                ),
                                                Text(
                                                  "도장 부여",
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    Divider(
                        color: Colors.grey.shade200,
                        height: 1,
                        indent: 16,
                        endIndent: 16),
                  ],
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  // 날짜 포맷팅 함수 개선
  String _formatDate(String? dateString) {
    if (dateString == null) return '';

    try {
      final dateTime = DateTime.parse(dateString);

      // 년/월/일 형식으로 표시 (더 직관적으로)
      final y = dateTime.year.toString().substring(2); // 년도 뒤 2자리
      final m = dateTime.month.toString().padLeft(2, '0');
      final d = dateTime.day.toString().padLeft(2, '0');

      return '$m.$d';
    } catch (e) {
      // 날짜 형식이 아닌 경우 원본 그대로 반환 (최대 10자)
      return dateString.length > 10 ? dateString.substring(0, 10) : dateString;
    }
  }

  // 날짜 문자열 길이 제한 함수
  int min(int a, int b) {
    return a < b ? a : b;
  }

  void _toggleTaskCompletion(
      String studentId, String taskName, bool completed, bool isGroupTask) {
    // TaskProvider 참조
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final isOffline = taskProvider.isOffline;

    print('도장 토글: 학생=$studentId, 과제=$taskName, 완료=$completed, 그룹=$isGroupTask');

    // 개인줄넘기 과제의 경우, 순차적 진행 여부 확인
    if (!isGroupTask && completed) {
      // 수정: TaskModel의 정적 메서드 사용
      final currentTask = TaskModel.getIndividualTasks().firstWhere(
        (task) => task.name == taskName,
        orElse: () => const TaskModel(id: 0, name: "", count: "", level: 0),
      );

      // 해당 학생 찾기
      final student = taskProvider.students.firstWhere(
        (s) => s.id == studentId,
        orElse: () => StudentProgress(
            id: "", name: "", classNum: '', group: '', studentNum: ''),
      );

      // 이미 완료된 과제인지 확인
      final isAlreadyCompleted =
          student.individualProgress[taskName]?.isCompleted ?? false;

      // 이미 완료된 경우 추가 확인 없이 진행
      if (isAlreadyCompleted) {
        _processTaskCompletion(studentId, taskName, completed, isGroupTask);
        return;
      }

      // 이전 단계 과제들을 모두 완료했는지 확인
      bool hasSkippedTasks = false;
      List<String> skippedTaskNames = [];

      // 수정: TaskModel의 정적 메서드 사용
      for (var task in TaskModel.getIndividualTasks()) {
        // 현재 과제보다 낮은 레벨의 과제만 확인
        if (task.level < currentTask.level) {
          // 이전 단계 과제가 완료되지 않았는지 확인
          final isCompleted =
              student.individualProgress[task.name]?.isCompleted ?? false;
          if (!isCompleted) {
            hasSkippedTasks = true;
            skippedTaskNames.add(task.name);
          }
        }
      }

      // iOS 스타일 경고 대화상자 - 건너뛴 과제가 있는 경우
      if (hasSkippedTasks) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('단계 순서 확인'),
            content: Column(
              children: [
                const SizedBox(height: 8),
                Text('${student.name} 학생은 이전 단계를 아직 완료하지 않았습니다:'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: skippedTaskNames
                        .map((name) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(
                                      CupertinoIcons
                                          .exclamationmark_triangle_fill,
                                      color: CupertinoColors.systemOrange,
                                      size: 16),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('개인줄넘기는 단계적으로 진행하는 것이 권장됩니다. 그래도 도장을 부여하시겠습니까?'),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('취소'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              CupertinoDialogAction(
                child: const Text('진행',
                    style: TextStyle(color: CupertinoColors.systemOrange)),
                onPressed: () {
                  Navigator.of(context).pop();
                  _processTaskCompletion(
                      studentId, taskName, completed, isGroupTask);
                },
              ),
            ],
          ),
        );
      } else {
        // 건너뛴 과제가 없으면 바로 진행
        _processTaskCompletion(studentId, taskName, completed, isGroupTask);
      }
    } else {
      // 단체줄넘기거나 도장 취소의 경우 바로 진행
      _processTaskCompletion(studentId, taskName, completed, isGroupTask);
    }
  }

  // 실제 도장 처리 로직을 별도 메서드로 분리
  void _processTaskCompletion(
      String studentId, String taskName, bool completed, bool isGroupTask) {
    // TaskProvider 참조
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final isOffline = taskProvider.isOffline;

    // iOS 스타일 알림 대화상자 표시
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(completed ? '과제 성공 도장 부여' : '과제 성공 도장 취소'),
        content: Text(completed
            ? '$taskName 과제에 성공 도장을 부여하시겠습니까?'
            : '$taskName 과제의 성공 도장을 취소하시겠습니까?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            isDefaultAction: true,
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            child: Text(
              completed ? '도장 부여' : '도장 취소',
              style: TextStyle(
                color: completed
                    ? CupertinoColors.activeBlue
                    : CupertinoColors.systemRed,
              ),
            ),
            onPressed: () async {
              Navigator.of(context).pop();

              // iOS 스타일 로딩 표시
              showCupertinoDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CupertinoActivityIndicator(radius: 16),
                        const SizedBox(height: 12),
                        Text(
                          completed ? '도장 부여 중' : '도장 취소 중',
                          style: const TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.label,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              try {
                // TaskProvider를 통해 상태 업데이트
                await taskProvider.updateTaskStatus(
                    studentId, taskName, completed, isGroupTask);

                // 성공 시 로딩 닫기
                Navigator.of(context).pop();

                // 성공 메시지 표시 - iOS 스타일 배너
                showCupertinoDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (context) => Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Container(
                        width: MediaQuery.of(context).size.width - 40,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: completed
                              ? CupertinoColors.systemGreen.withOpacity(0.9)
                              : CupertinoColors.systemOrange.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              completed
                                  ? CupertinoIcons.checkmark_circle_fill
                                  : CupertinoIcons.exclamationmark_circle_fill,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                completed
                                    ? '$taskName 과제에 성공 도장을 부여했습니다.'
                                    : '$taskName 과제의 성공 도장을 취소했습니다.',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                // 1.5초 후에 배너 자동 닫기
                Future.delayed(const Duration(milliseconds: 1500), () {
                  Navigator.of(context, rootNavigator: true).pop();
                });

                // 매우 중요: UI 강제 갱신
                setState(() {});
              } catch (e) {
                // 로딩 닫기
                Navigator.of(context).pop();

                // 오류 발생 시 iOS 스타일 오류 배너 표시
                showCupertinoDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (context) => Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Container(
                        width: MediaQuery.of(context).size.width - 40,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isOffline
                              ? CupertinoColors.systemOrange.withOpacity(0.9)
                              : CupertinoColors.systemRed.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isOffline
                                  ? CupertinoIcons.wifi_slash
                                  : CupertinoIcons.exclamationmark_circle_fill,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isOffline ? '오프라인 모드' : '오류 발생',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isOffline
                                        ? '변경 사항은 로컬에 저장되었으며 네트워크 연결 시 동기화됩니다.'
                                        : '오류: $e',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isOffline)
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                child: const Text(
                                  '동기화',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  taskProvider.syncData();
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                // 3초 후에 배너 자동 닫기 (오류는 더 오래 표시)
                Future.delayed(const Duration(milliseconds: 3000), () {
                  Navigator.of(context, rootNavigator: true).pop();
                });

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
