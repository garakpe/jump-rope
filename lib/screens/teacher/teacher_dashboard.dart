// lib/screens/teacher/teacher_dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/student_provider.dart';
import 'group_management.dart';
import 'progress_management.dart';
import 'reflection_management.dart';
import 'student_upload_screen.dart';
import '../../utils/constants.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({Key? key}) : super(key: key);

  @override
  _TeacherDashboardState createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedClassId = 0;

  // 학급 샘플 데이터
  final List<Map<String, dynamic>> _classes = List.generate(
    9,
    (index) => {
      'id': index + 1,
      'name': '${index + 1}반',
    },
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context);
    final isOffline = taskProvider.isOffline;

    return Scaffold(
      appBar: _buildAppBar(authProvider, taskProvider, isOffline),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            // 상단 헤더 영역
            _buildHeaderCard(isOffline, taskProvider),
            const SizedBox(height: AppSpacing.md),

            // 탭바
            _buildTabBar(),
            const SizedBox(height: AppSpacing.md),

            // 탭 내용
            Expanded(
              child: _selectedClassId == 0
                  ? _buildNoClassSelectedView()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        GroupManagement(selectedClassId: _selectedClassId),
                        ProgressManagement(selectedClassId: _selectedClassId),
                        ReflectionManagement(selectedClassId: _selectedClassId),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      AuthProvider authProvider, TaskProvider taskProvider, bool isOffline) {
    return AppBar(
      title: Row(
        children: [
          const Text(AppStrings.teacherAppTitle),
          if (isOffline)
            Container(
              margin: const EdgeInsets.only(left: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off,
                      size: 14, color: Colors.orange.shade800),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '오프라인',
                    style: TextStyle(
                      fontSize: AppSizes.fontSizeXS,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        if (isOffline)
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: '데이터 동기화',
            onPressed: () {
              taskProvider.syncData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text(AppStrings.syncInProgress)),
              );
            },
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Text(
                '${authProvider.userInfo?.name} 선생님',
                style: const TextStyle(
                  fontSize: AppSizes.fontSizeSM,
                  color: AppColors.textSecondary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => authProvider.logout(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard(bool isOffline, TaskProvider taskProvider) {
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
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade500, Colors.indigo.shade500],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: const Text(
                    '줄넘기 과제 관리',
                    style: TextStyle(
                      fontSize: AppSizes.fontSizeXL,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                ),

                // 오프라인 상태 표시
                if (isOffline) _buildOfflineStatusIndicator(taskProvider),
              ],
            ),
            Row(
              children: [
                // 학생 일괄 등록 버튼
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('학생 일괄 등록'),
                  onPressed: () => _navigateToStudentUpload(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // 학급 선택 드롭다운
                _buildClassSelector(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Container _buildOfflineStatusIndicator(TaskProvider taskProvider) {
    return Container(
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '오프라인 모드',
            style: TextStyle(
              color: Colors.orange.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ElevatedButton(
            onPressed: () => _showSyncDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('동기화 관리'),
          ),
        ],
      ),
    );
  }

  Container _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        boxShadow: AppShadows.small,
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.individualLight,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: AppColors.individualPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        tabs: const [
          Tab(
            icon: Icon(Icons.group),
            text: AppStrings.groupManagement,
          ),
          Tab(
            icon: Icon(Icons.school),
            text: AppStrings.learningStatus,
          ),
          Tab(
            icon: Icon(Icons.book),
            text: AppStrings.reflectionManagement,
          ),
        ],
      ),
    );
  }

  Widget _buildClassSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.individualLight,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedClassId == 0 ? null : _selectedClassId,
          hint: const Text(AppStrings.selectClass),
          icon: const Icon(Icons.arrow_drop_down,
              color: AppColors.individualPrimary),
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          items: _classes.map((cls) {
            return DropdownMenuItem<int>(
              value: cls['id'],
              child: Text(cls['name']),
            );
          }).toList(),
          onChanged: (value) => _handleClassSelection(value),
        ),
      ),
    );
  }

  void _handleClassSelection(int? value) {
    if (value != null) {
      setState(() {
        _selectedClassId = value;
      });

      // 클래스 숫자를 문자열로 변환
      final classNumString = value.toString();

      // 프로바이더에 클래스 정보 전달
      Provider.of<StudentProvider>(context, listen: false)
          .setSelectedClass(classNumString);
      Provider.of<TaskProvider>(context, listen: false)
          .selectClass(classNumString);

      // 첫 번째 탭으로 이동
      _tabController.animateTo(0);
    }
  }

  Future<void> _navigateToStudentUpload() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StudentUploadScreen(),
      ),
    );

    // 학생 업로드 결과 처리
    if (result != null && result is Map && result.containsKey('refreshClass')) {
      final classNumString = result['refreshClass'].toString();
      if (classNumString.isNotEmpty) {
        final classNumInt = int.tryParse(classNumString);
        if (classNumInt != null) {
          setState(() {
            _selectedClassId = classNumInt;
          });

          // 데이터 로드
          Provider.of<StudentProvider>(context, listen: false)
              .setSelectedClass(classNumString);
          Provider.of<TaskProvider>(context, listen: false)
              .selectClass(classNumString);

          // 첫 번째 탭으로 이동
          _tabController.animateTo(0);
        }
      }
    }
  }

  // 동기화 관리 대화상자
  void _showSyncDialog() {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.sync_problem, color: Colors.orange.shade700),
            const SizedBox(width: AppSpacing.sm),
            const Text('오프라인 변경 관리'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '네트워크 연결이 불안정하여 일부 데이터 변경사항이 서버에 동기화되지 않았습니다.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              '옵션:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppSpacing.sm),
            Text('1. 지금 동기화: 데이터 동기화를 즉시 시도합니다.'),
            Text('2. 로컬 상태 유지: 변경사항을 로컬에 계속 저장하고 나중에 동기화합니다.'),
            SizedBox(height: AppSpacing.md),
            Text(
              '주의: 동기화 전까지 변경사항은 다른 기기에서 볼 수 없습니다.',
              style: TextStyle(
                  color: AppColors.error, fontSize: AppSizes.fontSizeXS),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('나중에 하기'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.sync),
            label: const Text('지금 동기화'),
            onPressed: () => _syncData(context),
          ),
        ],
      ),
    );
  }

  void _syncData(BuildContext dialogContext) {
    Navigator.pop(dialogContext);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    // 동기화 시도 및 결과 알림
    taskProvider.syncData().then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.syncComplete),
          backgroundColor: AppColors.success,
        ),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('동기화 오류: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    });
  }

  Widget _buildNoClassSelectedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.class_,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            AppStrings.noClassSelected,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppSizes.fontSizeMD,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // 학생 등록 안내 추가
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            width: 400,
            decoration: BoxDecoration(
              color: AppColors.individualLight,
              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
              border: Border.all(color: AppColors.individualLight),
            ),
            child: const Column(
              children: [
                Text(
                  '시작하기',
                  style: TextStyle(
                    fontSize: AppSizes.fontSizeLG,
                    fontWeight: FontWeight.bold,
                    color: AppColors.individualPrimary,
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  '1. 상단의 "학생 일괄 등록" 버튼을 클릭해 엑셀 파일로 학생 명단을 업로드하세요.\n'
                  '2. 학급을 선택하여 학생들의 현황을 확인하고 관리할 수 있습니다.\n'
                  '3. 모둠 관리 탭에서 학생들의 모둠을 구성하세요.',
                  style: TextStyle(fontSize: AppSizes.fontSizeSM),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
