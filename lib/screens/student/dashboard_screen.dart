// lib/screens/student/dashboard_screen.dart
// dashboard_screen.dart 파일의 import 부분
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/task_card.dart';
import './progress_screen.dart'; // 진도 화면
import './reflection_screen.dart'; // 성찰 화면 (이름 충돌 해결)
import '../../models/ui_models.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({Key? key}) : super(key: key);

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with SingleTickerProviderStateMixin {
  NavigationTab _currentTab = NavigationTab.dashboard;
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
      appBar: AppBar(
        title: Row(
          children: [
            const Text('줄넘기 학습 관리'),
            if (isOffline)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
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
                  const SnackBar(content: Text('데이터 동기화 중...')),
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${user?.className}학년 ${user?.classNum}반 ${user?.group}모둠 ${user?.name}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
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
      ),
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

// lib/screens/student/dashboard_screen.dart의 _buildBody 메서드 부분 수정

  Widget _buildBody() {
    switch (_currentTab) {
      case NavigationTab.dashboard:
        return _buildDashboardContent();
      case NavigationTab.progress:
        // 진도 화면
        return const ProgressScreen();
      case NavigationTab.reflection:
        // 성찰 화면
        return const ReflectionScreen();
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    return Column(
      children: [
        // 상단 탭바
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey.shade600,
            tabs: const [
              Tab(text: '개인줄넘기'),
              Tab(text: '단체줄넘기'),
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

// lib/screens/student/dashboard_screen.dart 파일의 _buildTaskGrid 메서드 부분만 수정

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

    // 디버그 정보 출력
    print('학생 대시보드 - 그룹: $group, 단체줄넘기 허용: $canDoGroupTasks');

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.9,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
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

  // 단체줄넘기 시작 조건 확인 함수
  bool _canStartGroupActivities(TaskProvider provider, int group) {
    // 같은 그룹의 모든 학생 찾기
    final groupStudents =
        provider.students.where((s) => s.group == group).toList();

    if (groupStudents.isEmpty) return false;

    // 그룹의 모든 학생의 개인줄넘기 성공 수 합계
    int totalSuccesses = 0;
    for (var student in groupStudents) {
      totalSuccesses +=
          student.individualProgress.values.where((p) => p.isCompleted).length;
    }

    // 필요한 성공 개수: 학생 수 × 5
    int neededSuccesses = groupStudents.length * 5;

    return totalSuccesses >= neededSuccesses;
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
            color: Colors.white,
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
                                ? Colors.blue.shade100 // 개인줄넘기
                                : Colors.green.shade100), // 단체줄넘기
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCompleted
                            ? Icons.check_circle
                            : (task.isIndividual ? Icons.person : Icons.people),
                        color: isCompleted
                            ? Colors.amber.shade600
                            : (task.isIndividual
                                ? Colors.blue.shade600
                                : Colors.green.shade600),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '목표: ${task.count}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? Colors.amber.shade50
                                      : (task.isIndividual
                                          ? Colors.blue.shade50
                                          : Colors.green.shade50),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isCompleted ? '성공!' : '도전 중',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isCompleted
                                        ? Colors.amber.shade700
                                        : (task.isIndividual
                                            ? Colors.blue.shade700
                                            : Colors.green.shade700),
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
                          fontSize: 18,
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.videocam,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '해당 동작의 시범 영상이 표시됩니다',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 동작 설명
                      const Text(
                        '동작 설명',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        task.description,
                        style: TextStyle(
                          height: 1.5,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 평가 기준
                      const Text(
                        '평가 기준',
                        style: TextStyle(
                          fontSize: 18,
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
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
