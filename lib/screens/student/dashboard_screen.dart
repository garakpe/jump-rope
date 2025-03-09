// lib/screens/student/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/task_card.dart';
import './progress_screen.dart';
import './reflection_screen.dart';
import './home_screen.dart'; // 새로 추가된 홈 화면
import '../../models/ui_models.dart';
import '../../utils/constants.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({Key? key}) : super(key: key);

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with SingleTickerProviderStateMixin {
  NavigationTab _currentTab = NavigationTab.home; // 시작 탭을 홈으로 변경
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    final user = authProvider.userInfo;
    final isOffline = taskProvider.isOffline;

    return Scaffold(
      appBar: _buildAppBar(user, isOffline, taskProvider, authProvider),
      body: _buildBody(),
      bottomNavigationBar: BottomNavBar(
        currentTab: _currentTab,
        onTabSelected: (tab) {
          setState(() {
            _currentTab = tab;
          });
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      user, isOffline, TaskProvider taskProvider, AuthProvider authProvider) {
    return AppBar(
      title: Row(
        children: [
          const Text(AppStrings.appTitle),
          if (isOffline)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
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
                '${user?.className}학년 ${user?.classNum}반 ${user?.group}모둠 ${user?.name}',
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

  Widget _buildBody() {
    switch (_currentTab) {
      case NavigationTab.home:
        return const HomeScreen(); // 새로운 홈 화면
      case NavigationTab.task:
        return _buildTaskContent(); // 이름 변경된 메서드
      case NavigationTab.progress:
        return const ProgressScreen();
      case NavigationTab.reflection:
        return const ReflectionScreen();
      default:
        return const HomeScreen();
    }
  }

  // 기존 _buildDashboardContent 메서드를 _buildTaskContent로 이름 변경
  Widget _buildTaskContent() {
    return Column(
      children: [
        // 상단 탭바
        Container(
          margin: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppShadows.small,
            ),
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey.shade600,
            tabs: const [
              Tab(text: AppStrings.individualJumpRope),
              Tab(text: AppStrings.groupJumpRope),
            ],
          ),
        ),

        // 탭 내용
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTaskGrid(individualTasks, true), // 개인줄넘기
              _buildTaskGrid(groupTasks, false), // 단체줄넘기
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaskGrid(List<TaskModel> tasks, bool isIndividual) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final currentLevel = taskProvider.currentLevel;

    // 현재 로그인한 사용자 정보 가져오기
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userInfo;
    final studentId = user?.studentId ?? '';

    // 현재 학생의 진도 정보 찾기
    final currentStudent = taskProvider.students.firstWhere(
        (s) => s.id == studentId,
        orElse: () =>
            StudentProgress(id: studentId, name: '', number: 0, group: 0));

    // 학생의 그룹 찾기
    final group = int.tryParse(user?.group ?? '1') ?? 1;

    // 단체줄넘기 허용 여부 확인
    bool canDoGroupTasks = false;
    try {
      canDoGroupTasks = taskProvider.canStartGroupActivities(group);
    } catch (e) {
      print('단체줄넘기 허용 여부 확인 오류: $e');
    }

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.9,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];

        // 활성화 여부 결정
        final bool isActive = isIndividual
            ? task.level <= currentLevel // 개인줄넘기: 현재 레벨 이하만 도전 가능
            : canDoGroupTasks; // 단체줄넘기: 모둠 자격 충족해야 도전 가능

        // 과제 완료 여부 확인
        bool isCompleted = false;
        if (isIndividual) {
          final progress = currentStudent.individualProgress[task.name];
          isCompleted = progress?.isCompleted ?? false;
        } else {
          final progress = currentStudent.groupProgress[task.name];
          isCompleted = progress?.isCompleted ?? false;
        }

        return TaskCard(
          task: task,
          isActive: isActive,
          isCompleted: isCompleted,
          currentLevel: currentLevel,
          onTap: isActive ? () => _showTaskModal(task, isCompleted) : null,
        );
      },
    );
  }

  void _showTaskModal(TaskModel task, bool isCompleted) {
    if (mounted) {
      setState(() {});
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 헤더 영역
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.amber.shade100 // 성공 시 황금색
                            : (task.isIndividual
                                ? AppColors.individualLight // 개인줄넘기
                                : AppColors.groupLight), // 단체줄넘기
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCompleted
                            ? Icons.check_circle
                            : (task.isIndividual ? Icons.person : Icons.people),
                        color: isCompleted
                            ? Colors.amber.shade600
                            : (task.isIndividual
                                ? AppColors.individualPrimary
                                : AppColors.groupPrimary),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.name,
                            style: const TextStyle(
                              fontSize: AppSizes.fontSizeXL,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '목표: ${task.count}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? Colors.amber.shade50
                                      : (task.isIndividual
                                          ? AppColors.individualLight
                                          : AppColors.groupLight),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isCompleted ? '성공!' : '도전 중',
                                  style: TextStyle(
                                    fontSize: AppSizes.fontSizeXS,
                                    fontWeight: FontWeight.bold,
                                    color: isCompleted
                                        ? Colors.amber.shade700
                                        : (task.isIndividual
                                            ? AppColors.individualPrimary
                                            : AppColors.groupPrimary),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // 상세 내용 영역
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '시범 영상',
                        style: TextStyle(
                          fontSize: AppSizes.fontSizeLG,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 영상 영역 (데모 표시)
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.videocam,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: AppSpacing.sm),
                            Text(
                              '해당 동작의 시범 영상이 표시됩니다',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // 동작 설명
                      const Text(
                        '동작 설명',
                        style: TextStyle(
                          fontSize: AppSizes.fontSizeLG,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        task.description,
                        style: const TextStyle(
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // 평가 기준
                      const Text(
                        '평가 기준',
                        style: TextStyle(
                          fontSize: AppSizes.fontSizeLG,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCriteriaItem('정확한 자세로 수행하기'),
                      _buildCriteriaItem('목표 횟수 달성하기'),
                      _buildCriteriaItem('연속 동작 유지하기'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      setState(() {});
    });
  }

  Widget _buildCriteriaItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 16, color: AppColors.success),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
