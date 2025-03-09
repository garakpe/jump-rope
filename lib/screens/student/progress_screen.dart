// lib/screens/student/progress_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../models/ui_models.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final currentWeek = taskProvider.currentWeek;
    final stampCount = taskProvider.stampCount;
    final students = taskProvider.students;
    final isLoading = taskProvider.isLoading;

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          // 주차 및 도장 개수 표시 카드
          _buildHeaderCard(currentWeek, stampCount),
          const SizedBox(height: AppSpacing.md),

          // 진도표 카드
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 1200, // 넓은 테이블을 위한 고정 너비
                  child: _buildProgressTable(context, students),
                ),
              ),
            ),
          ),

          // 안내문 카드
          _buildInstructionCard(),
        ],
      ),
    );
  }

  Card _buildHeaderCard(int currentWeek, int stampCount) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '($currentWeek주차) 모둠 줄넘기 진도표',
                  style: const TextStyle(
                    fontSize: AppSizes.fontSizeLG,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.individualLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '확인 도장 개수: $stampCount개',
                    style: const TextStyle(
                      color: AppColors.individualPrimary,
                      fontWeight: FontWeight.bold,
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

  Widget _buildProgressTable(
      BuildContext context, List<StudentProgress> students) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userInfo;
    final group = int.tryParse(user?.group ?? '1') ?? 1;

    // 내 학생 ID 찾기
    final myId = user?.studentId ?? '';

    // 모둠 정보를 가져와서 모둠원 필터링
    final groupStudents = students.where((s) => s.group == group).toList();
    groupStudents.sort((a, b) => a.name.compareTo(b.name)); // 이름순 정렬

    // 모둠 자격 조건 확인 (단체줄넘기 활성화 여부)
    bool canDoGroupTask = false;
    try {
      canDoGroupTask = taskProvider.canStartGroupActivities(group);
    } catch (e) {
      print('단체줄넘기 자격 확인 오류: $e');
    }

    return DataTable(
      columnSpacing: 10,
      headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
      border: TableBorder.all(
        color: Colors.grey.shade300,
        width: 1,
      ),
      columns: _buildTableColumns(),
      rows: _buildTableRows(groupStudents, myId),
    );
  }

  List<DataColumn> _buildTableColumns() {
    return [
      const DataColumn(
        label: Text(
          '모둠원',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      ...individualTasks.map((task) => DataColumn(
            label: Expanded(
              child: Text(
                '${task.name}\n${task.count}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: AppSizes.fontSizeXS),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )),
      ...groupTasks.map((task) => DataColumn(
            label: Expanded(
              child: Text(
                '${task.name}\n${task.count}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: AppSizes.fontSizeXS),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )),
    ];
  }

  List<DataRow> _buildTableRows(
      List<StudentProgress> groupStudents, String myId) {
    return groupStudents.map((student) {
      // 현재 학생 강조 표시
      final isCurrentStudent = student.id == myId;

      return DataRow(
        color: isCurrentStudent
            ? WidgetStateProperty.all(AppColors.individualLight)
            : null,
        cells: [
          DataCell(
            Text(
              student.name + (isCurrentStudent ? ' (나)' : ''),
              style: TextStyle(
                fontWeight:
                    isCurrentStudent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          ..._buildTaskCells(student, individualTasks, true),
          ..._buildTaskCells(student, groupTasks, false),
        ],
      );
    }).toList();
  }

  List<DataCell> _buildTaskCells(
      StudentProgress student, List<TaskModel> tasks, bool isIndividual) {
    return tasks.map((task) {
      final progress = isIndividual
          ? student.individualProgress[task.name]
          : student.groupProgress[task.name];
      final isCompleted = progress?.isCompleted ?? false;
      final completionDate = progress?.completedDate;

      final cellColor = isIndividual
          ? (isCompleted ? AppColors.individualLight : null)
          : (isCompleted ? AppColors.groupLight : null);
      final iconColor =
          isIndividual ? AppColors.individualPrimary : AppColors.groupPrimary;

      return DataCell(
        Container(
          color: cellColor,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isCompleted) Icon(Icons.check_circle, color: iconColor),
              if (isCompleted && completionDate != null)
                Text(
                  _formatDate(completionDate),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Card _buildInstructionCard() {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(top: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '* 개인줄넘기 영역은 단계적으로 진도 나갈 것',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppSizes.fontSizeSM),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              '* 확인도장 20개 이상일 경우부터 단체줄넘기 시도할 수 있음',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppSizes.fontSizeSM),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              '* 단체줄넘기 영역은 선택적으로 시도할 수 있음',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppSizes.fontSizeSM),
            ),
          ],
        ),
      ),
    );
  }

  // 날짜 포맷팅 함수
  String _formatDate(String? dateString) {
    if (dateString == null) return '';

    try {
      final dateTime = DateTime.parse(dateString);

      // 간단한 날짜 포맷 (년/월/일)
      final y = dateTime.year.toString().substring(2); // 년도 뒤 2자리
      final m = dateTime.month.toString().padLeft(2, '0');
      final d = dateTime.day.toString().padLeft(2, '0');

      return '$y/$m/$d';
    } catch (e) {
      // 날짜 형식이 아닌 경우 원본 그대로 반환 (최대 10자)
      return dateString.length > 10 ? dateString.substring(0, 10) : dateString;
    }
  }
}
