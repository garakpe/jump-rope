// lib/screens/teacher/progress_management.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../models/ui_models.dart';
import '../../utils/constants.dart';

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
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final students = taskProvider.students;
    final isLoading = taskProvider.isLoading;
    final isOffline = taskProvider.isOffline;

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
            const SizedBox(height: AppSpacing.md),
            const Text(
              AppStrings.noClassSelected,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 헤더 카드
        _buildHeaderCard(),
        const SizedBox(height: AppSpacing.md),

        // 오프라인 모드 알림
        if (isOffline) _buildOfflineAlert(taskProvider),

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
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.school,
                  color: _viewMode == 'individual'
                      ? AppColors.individualPrimary
                      : AppColors.groupPrimary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${widget.selectedClassId}반 학습 현황',
                  style: TextStyle(
                    fontSize: AppSizes.fontSizeLG,
                    fontWeight: FontWeight.bold,
                    color: _viewMode == 'individual'
                        ? AppColors.individualPrimary
                        : AppColors.groupPrimary,
                  ),
                ),
              ],
            ),
            _buildViewModeSelector(),
          ],
        ),
      ),
    );
  }

  Container _buildViewModeSelector() {
    return Container(
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
                    ? AppColors.white
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                AppStrings.individualJumpRope,
                style: TextStyle(
                  color: _viewMode == 'individual'
                      ? AppColors.individualPrimary
                      : AppColors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: AppSizes.fontSizeSM,
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
                color:
                    _viewMode == 'group' ? AppColors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                AppStrings.groupJumpRope,
                style: TextStyle(
                  color: _viewMode == 'group'
                      ? AppColors.groupPrimary
                      : AppColors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: AppSizes.fontSizeSM,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineAlert(TaskProvider taskProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              AppStrings.offlineMode,
              style: TextStyle(color: Colors.orange.shade700),
            ),
          ),
          TextButton(
            onPressed: () {
              taskProvider.syncData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text(AppStrings.syncInProgress)),
              );
            },
            child: Text(
              '동기화',
              style: TextStyle(color: Colors.orange.shade700),
            ),
          ),
        ],
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

          return _buildGroupCard(groupNum, groupStudents, tasks, qualification);
        }).toList(),
      ),
    );
  }

  Card _buildGroupCard(int groupNum, List<StudentProgress> groupStudents,
      List<TaskModel> tasks, QualificationStatus qualification) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 모둠 헤더
          _buildGroupHeader(groupNum, groupStudents, qualification),

          // 진도표
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: _buildGroupDataTable(groupStudents, tasks),
            ),
          ),

          // 단체줄넘기 자격 알림 (개인줄넘기 탭에서만 표시)
          if (_viewMode == 'individual' && !qualification.qualified)
            _buildQualificationAlert(qualification),
        ],
      ),
    );
  }

  Container _buildGroupHeader(int groupNum, List<StudentProgress> groupStudents,
      QualificationStatus qualification) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _viewMode == 'individual'
            ? AppColors.individualLight
            : AppColors.groupLight,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppSizes.borderRadius),
          topRight: Radius.circular(AppSizes.borderRadius),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$groupNum모둠 (${groupStudents.length}명)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: AppSizes.fontSizeMD,
              color: _viewMode == 'individual'
                  ? AppColors.individualPrimary
                  : AppColors.groupPrimary,
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
                    ? AppColors.groupLight
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                qualification.qualified
                    ? '단체줄넘기 시작 가능!'
                    : '개인 성공 ${qualification.count}/${qualification.needed}',
                style: TextStyle(
                  color: qualification.qualified
                      ? AppColors.groupPrimary
                      : Colors.grey.shade800,
                  fontSize: AppSizes.fontSizeXS,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  DataTable _buildGroupDataTable(
      List<StudentProgress> groupStudents, List<TaskModel> tasks) {
    return DataTable(
      columnSpacing: 10,
      headingRowColor: WidgetStateProperty.all(
        _viewMode == 'individual'
            ? AppColors.individualLight
            : AppColors.groupLight,
      ),
      dataRowColor: WidgetStateProperty.all(AppColors.white),
      border: TableBorder.all(
        color: Colors.grey.shade300,
        width: 1,
      ),
      columns: [
        const DataColumn(
          label: Text('모둠원', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const DataColumn(
          label: Center(
            child: Text('출석', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          fontSize: AppSizes.fontSizeXS),
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
            _buildStudentNameCell(student),
            _buildAttendanceCell(student),
            ...tasks.map((task) => _buildTaskCell(student, task)),
          ],
        );
      }).toList(),
    );
  }

  DataCell _buildStudentNameCell(StudentProgress student) {
    return DataCell(
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
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            student.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  DataCell _buildAttendanceCell(StudentProgress student) {
    return DataCell(
      Center(
        child: student.attendance
            ? const Icon(Icons.check_circle, color: AppColors.success)
            : const Icon(Icons.cancel, color: AppColors.error),
      ),
    );
  }

  DataCell _buildTaskCell(StudentProgress student, TaskModel task) {
    final isIndividual = _viewMode == 'individual';
    final progress = isIndividual
        ? student.individualProgress[task.name]
        : student.groupProgress[task.name];
    final isCompleted = progress?.isCompleted ?? false;
    final completionDate = progress?.completedDate;

    return DataCell(
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              _handleTaskClick(student, task, isCompleted, isIndividual),
          child: Ink(
            width: double.infinity,
            height: double.infinity,
            color: isCompleted
                ? (isIndividual
                    ? AppColors.individualLight
                    : AppColors.groupLight)
                : null,
            child: Center(
              child: isCompleted
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: isIndividual
                              ? AppColors.individualPrimary
                              : AppColors.groupPrimary,
                          size: 24,
                        ),
                        if (completionDate != null)
                          Positioned(
                            bottom: 0,
                            child: Text(
                              _formatDate(completionDate),
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
  }

  Container _buildQualificationAlert(QualificationStatus qualification) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.individualLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.individualPrimary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    color: AppColors.individualPrimary,
                    fontSize: AppSizes.fontSizeSM),
                children: [
                  const TextSpan(
                    text: '개인줄넘기 목표: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: '${qualification.count}/${qualification.needed} 완료',
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
    );
  }

  void _handleTaskClick(StudentProgress student, TaskModel task,
      bool isCompleted, bool isIndividual) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final qualification = _checkGroupQualification([student]);

    // 단체줄넘기는 자격 있을 때만 체크 가능
    bool canToggle = true;
    if (!isIndividual && !isCompleted) {
      // 단체줄넘기는 자격 조건 확인 (전체 모둠으로 확인)
      final groupStudents =
          taskProvider.students.where((s) => s.group == student.group).toList();
      final groupQualification = _checkGroupQualification(groupStudents);
      canToggle = groupQualification.qualified;
    }

    if (student.attendance && canToggle) {
      // 도장 토글 다이얼로그 표시
      _showToggleTaskDialog(student.id, task.name, !isCompleted, !isIndividual);
    } else if (!canToggle && !isIndividual && !isCompleted) {
      // 단체줄넘기 자격이 없는 경우 안내
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '단체줄넘기는 개인줄넘기 성공 도장 ${qualification.needed}개 이상 획득 시 시작할 수 있습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showToggleTaskDialog(
      String studentId, String taskName, bool completed, bool isGroupTask) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final isOffline = taskProvider.isOffline;

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
            onPressed: () => _processTaskUpdate(
                studentId, taskName, completed, isGroupTask, context),
          ),
        ],
      ),
    );
  }

  Future<void> _processTaskUpdate(String studentId, String taskName,
      bool completed, bool isGroupTask, BuildContext dialogContext) async {
    Navigator.of(dialogContext).pop();
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final isOffline = taskProvider.isOffline;

    // 로딩 표시
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.md),
            Text('${completed ? '도장 부여' : '도장 취소'} 중...'),
          ],
        ),
        duration: const Duration(seconds: 60), // 긴 시간 설정
        backgroundColor: AppColors.individualPrimary,
      ),
    );

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
          backgroundColor: completed ? AppColors.success : Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

      // UI 강제 갱신
      setState(() {});
    } catch (e) {
      // 오류 발생 시 기존 스낵바 제거 후 오류 메시지 표시
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // 오프라인 상태면 다른 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isOffline ? AppStrings.offlineMode : '오류 발생: $e'),
          backgroundColor: isOffline ? Colors.orange : AppColors.error,
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
    }
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
}

// 모둠 단체줄넘기 자격 상태를 담는 클래스
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
