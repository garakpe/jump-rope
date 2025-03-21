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
import '../../models/ui_models.dart';
import 'package:flutter/cupertino.dart';

// 현재 학생의 진도 정보 찾기 (간결화된 버전)
StudentProgress getCurrentStudent(TaskProvider taskProvider, String studentId) {
  // 캐시에서 먼저 확인
  final cachedStudent = taskProvider.getStudentFromCache(studentId);
  if (cachedStudent != null) {
    return cachedStudent;
  }

  return taskProvider.students.firstWhere(
      (s) => s.id == studentId || s.studentId == studentId,
      orElse: () => StudentProgress(
          id: studentId, name: '', number: 0, group: '', studentId: studentId));
}

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
    // 기본 탭을 홈으로 설정
    _currentTab = NavigationTab.home;
    // 화면이 처음 로드될 때 데이터 강제 새로고침
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  // 초기 데이터 로드 메서드 - 간결화
  void _loadInitialData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userInfo;
    final studentId = user?.studentId ?? '';

    if (studentId.isNotEmpty) {
      _loadStudentDataFromServer(studentId);
    }
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
          // 새로고침 버튼
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: () => _refreshData(user?.studentId ?? ''),
          ),

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
                  '${user?.grade}학년 ${user?.classNum}반 ${user?.group}모둠 ${user?.name}',
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

  // 데이터 새로고침 메서드 - 간결화
  void _refreshData(String studentId) {
    if (studentId.isEmpty) return;

    // 로딩 표시
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('데이터를 새로고침 중입니다...')),
    );

    // 데이터 새로고침 요청
    Provider.of<TaskProvider>(context, listen: false)
        .refreshStudentData(studentId)
        .then((_) {
      // 성공 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('데이터가 업데이트되었습니다'),
          backgroundColor: Colors.green,
        ),
      );
    }).catchError((e) {
      // 오류 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('새로고침 오류: $e'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  Widget _buildBody() {
    switch (_currentTab) {
      case NavigationTab.home:
        return _buildHomeContent();
      case NavigationTab.dashboard:
        return _buildDashboardContent();
      case NavigationTab.progress:
        return const ProgressScreen();
      case NavigationTab.reflection:
        return const ReflectionScreen();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    return Container(
      color: Colors.grey.shade50,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 앱 소개 헤더
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 16, top: 8),
              child: Text(
                '줄넘기 학습 관리',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                  letterSpacing: -0.5,
                ),
              ),
            ),

            // 앱 사용 방법 카드
            _buildIosStyleCard(
              title: '앱 사용 방법',
              icon: CupertinoIcons.app_badge,
              color: Colors.blue.shade600,
              children: [
                _buildListItem('과제 탭에서 개인 및 단체 줄넘기 과제를 확인하고 도전할 수 있습니다.'),
                _buildListItem(
                    '모든 조원은 서로 협력하여 앱에서 제시하는 여러 가지 줄넘기 방법을 단계별로 학습합니다.'),
                _buildListItem(
                    '줄넘기 연습 장소는 선생님의 시야를 벗어나지 않는 범위에서 적당한 곳을 선정하여 모둠별로 연습합니다.'),
                _buildListItem('개인줄넘기 단계는 반드시 이전 단계를 통과해야 다음 단계로 진행할 수 있습니다.'),
                _buildListItem('과제 수행 후 선생님께 확인 받으면 앱에서 도장이 찍힙니다.'),
                _buildListItem('성공한 과제는 진도 탭에서 실시간으로 확인할 수 있습니다.'),
              ],
            ),

            // 단체 과제 카드
            _buildIosStyleCard(
              title: '단체 줄넘기 진행 방법',
              icon: CupertinoIcons.person_3_fill,
              color: Colors.green.shade600,
              children: [
                _buildListItem(
                    '2인 이상 하는 줄넘기(짝 줄넘기, 긴 줄넘기)는 모둠 누적 확인 도장이 모둠원×5개 이상 있어야만 도전할 수 있습니다.'),
                _buildListItem(
                    '팀원은 서로 과제 도전을 도와주고, 성공 기준을 달성하면 선생님께 확인을 받습니다.'),
                _buildListItem('자세한 설명에도 이해가 안 되면 친구나 선생님에게 도움을 청할 수 있습니다.'),
                _buildListItem(
                    '모둠원들은 모든 모둠원이 가능한 빠른 시간 내에 정해진 진도를 모두 달성할 수 있도록 서로 협력해야 합니다.'),
              ],
            ),

            // 평가 방법 카드
            _buildIosStyleCard(
              title: '평가 방법',
              icon: CupertinoIcons.chart_bar_alt_fill,
              color: Colors.orange.shade600,
              children: [
                _buildListItem('매 수업시간마다 앱의 진도 탭에서 확인되는 진도를 기준으로 평가합니다.'),
                _buildListItem('단체 줄넘기는 모둠 확인도장이 모둠원×5개 이상부터 시도할 수 있습니다.'),
                _buildListItem('만점 기준:'),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildListItem('개인영역: 개인줄넘기 5단계 이상', bulletSize: 4),
                      _buildListItem('모둠영역: 모둠 전체 확인도장이 (모둠원 × 11)개 이상',
                          bulletSize: 4),
                      _buildListItem('예) 4명 모둠은 4 × 11 = 44개 이상 도장 시 만점',
                          bulletSize: 4),
                    ],
                  ),
                ),
              ],
            ),

            // 주의사항 카드
            _buildIosStyleCard(
              title: '주의사항',
              icon: CupertinoIcons.exclamationmark_triangle_fill,
              color: Colors.red.shade600,
              children: [
                _buildListItem('줄넘기 연습은 수업시간 내내 지속적으로 이루어져야 합니다.'),
                _buildListItem(
                    '줄넘기와 무관한 활동을 하는 학생이 있는 모둠은 체력 훈련 대상이 될 수 있습니다.'),
                _buildListItem('과제 확인은 반드시 선생님께 받아야 합니다.'),
                _buildListItem(
                    '수업시간에는 줄넘기만 해야 하며, 화장실이나 물 마시러 가는 것은 선생님의 허락이 필요합니다.'),
                _buildListItem(
                    '몸 상태가 좋지 않은, 환자는 선생님께 알리고 보건실 방문 후 모둠 활동을 관람할 수 있습니다.'),
              ],
            ),

            // 성공 전략 카드
            _buildIosStyleCard(
              title: '좋은 성적을 받으려면...',
              icon: CupertinoIcons.lightbulb_fill,
              color: Colors.amber.shade600,
              children: [
                _buildListItem(
                    '나만 잘해서는 팀 점수가 높아질 수 없습니다. 모둠원 모두가 잘해야 좋은 성적을 받을 수 있습니다.'),
                _buildListItem('줄넘기를 못 하는 친구를 도와 진도를 나갈 수 있게 도와주세요.'),
                _buildListItem('지금 여러분에게 필요한 것은... 스피드가 아닌 협동입니다.'),
              ],
            ),

            // 앱 버전 정보
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
              child: Text(
                '줄넘기 학습 관리 앱 v1.0',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // iOS 스타일 카드 위젯
  Widget _buildIosStyleCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카드 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: color.withOpacity(0.9),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          // 카드 내용
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  // 목록 항목 위젯
  Widget _buildListItem(String text, {double bulletSize = 6}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(
                top: 7, right: 8, left: bulletSize == 4 ? 0 : 4),
            width: bulletSize,
            height: bulletSize,
            decoration: BoxDecoration(
              color: Colors.grey.shade700,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Colors.grey.shade800,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
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
              _buildTaskGrid(true), // 개인줄넘기
              _buildTaskGrid(false), // 단체줄넘기
            ],
          ),
        ),
      ],
    );
  }

  // 과제 그리드 위젯 (리팩토링)
  Widget _buildTaskGrid(bool isIndividual) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userInfo;
    final studentId = user?.studentId ?? '';
    final groupId = user?.group ?? '';

    // 현재 학생의 진도 정보 찾기
    final currentStudent = getCurrentStudent(taskProvider, studentId);

    // 과제 목록 가져오기
    final tasks =
        isIndividual ? taskProvider.individualTasks : taskProvider.groupTasks;

    // 단체줄넘기 허용 여부 확인 - 모둠의 도장 갯수를 사용
    final canDoGroupTasks = taskProvider.canStartGroupActivities(groupId);

    // 로딩 상태 표시
    if (taskProvider.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('데이터를 불러오는 중입니다...'),
          ],
        ),
      );
    }

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

        // 과제 완료 여부 확인
        final progress = isIndividual
            ? currentStudent.individualProgress[task.name]
            : currentStudent.groupProgress[task.name];
        final isCompleted = progress?.isCompleted ?? false;

        // 과제 활성화 결정 (리팩토링)
        bool isActive = _isTaskActive(
            task, isIndividual, isCompleted, currentStudent, canDoGroupTasks);

        return TaskCard(
          task: task,
          isActive: isActive,
          isCompleted: isCompleted,
          currentLevel: task.level,
          onTap: (isActive || isCompleted)
              ? () => _showTaskModal(task, isCompleted)
              : null,
        );
      },
    );
  }

  // 과제 활성화 여부 결정 메서드 (추출)
  bool _isTaskActive(TaskModel task, bool isIndividual, bool isCompleted,
      StudentProgress student, bool canDoGroupTasks) {
    if (isCompleted) return true; // 이미 완료된 과제는 항상 활성화

    if (isIndividual) {
      // 개인 과제 활성화 로직
      if (task.level == 1) return true; // 1단계는 항상 활성화

      // 현재 완료한 최고 레벨 찾기
      int maxCompletedLevel = 0;

      // 완료된 과제들을 확인
      for (var entry in student.individualProgress.entries) {
        if (entry.value.isCompleted) {
          // 완료된 과제의 레벨 찾기
          final completedTask = TaskModel.getIndividualTasks().firstWhere(
            (t) => t.name == entry.key,
            orElse: () =>
                TaskModel(id: 0, name: entry.key, count: '', level: 0),
          );

          if (completedTask.level > maxCompletedLevel) {
            maxCompletedLevel = completedTask.level;
          }
        }
      }

      // 완료한 레벨의 바로 다음 레벨만 활성화
      return task.level <= maxCompletedLevel + 1;
    } else {
      // 단체 과제 활성화 로직 - 모둠 도장 개수 기준 적용
      return canDoGroupTasks;
    }
  }

  // 서버에서 학생 데이터 로드 - 간결화
  Future<void> _loadStudentDataFromServer(String studentId) async {
    if (studentId.isEmpty) return;

    try {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      await taskProvider.syncStudentDataFromServer(studentId);

      // 화면 갱신
      setState(() {});
    } catch (e) {
      print('학생 데이터 로드 오류: $e');
      setState(() {});
    }
  }

  void _showTaskModal(TaskModel task, bool isCompleted) {
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
                              if (!isCompleted)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Text(
                                    '${task.level}단계',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade600,
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
      // 모달이 닫힐 때 화면 갱신
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
