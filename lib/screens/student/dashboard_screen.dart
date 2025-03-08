// lib/screens/student/dashboard_screen.dart
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
import 'package:cloud_firestore/cloud_firestore.dart';

// 현재 학생의 진도 정보 찾기 (일관된 방식으로)
StudentProgress getCurrentStudent(TaskProvider taskProvider, String studentId) {
  // 캐시에서 먼저 확인
  final cachedStudent = taskProvider.getStudentFromCache(studentId);
  if (cachedStudent != null) {
    return cachedStudent;
  }

  // 없으면 목록에서 검색
  return taskProvider.students.firstWhere(
      (s) => s.id == studentId || s.id == studentId,
      orElse: () =>
          StudentProgress(id: studentId, name: '', number: 0, group: 0));
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
    // 화면이 처음 로드될 때 데이터 강제 새로고침
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 사용자 정보를 이용해 학생 ID 가져오기
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.userInfo;
      final studentId = user?.studentId ?? '';
      if (studentId.isNotEmpty) {
        // 강제로 서버에서 직접 데이터를 가져오는 함수 호출
        _loadStudentDataFromServer(studentId);
      }
    });
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
          // 새로고침 버튼 추가
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: () {
              // 로딩 표시
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('데이터를 새로고침 중입니다...')),
              );

              // 사용자 정보를 이용해 학생 ID 가져오기
              final studentId = user?.studentId ?? '';

              if (studentId.isNotEmpty) {
                // 데이터 새로고침 요청
                taskProvider.refreshStudentData(studentId).then((_) {
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
            },
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

  Widget _buildTaskGrid(List<TaskModel> tasks, bool isIndividual) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userInfo;
    final studentId = user?.studentId ?? '';

    // 현재 학생의 진도 정보 찾기 (캐시 우선 사용)
    StudentProgress currentStudent;

    // 캐시된 데이터 확인
    final cachedStudent = taskProvider.getStudentFromCache(studentId);
    if (cachedStudent != null) {
      currentStudent = cachedStudent;
      print('캐시에서 학생 데이터 사용: $studentId, 이름: ${cachedStudent.name}');
    } else {
      print('캐시에 학생 데이터 없음, 목록에서 검색: $studentId');
      // 캐시에 없으면 목록에서 검색
      try {
        currentStudent = taskProvider.students.firstWhere(
            (s) => s.id == studentId || s.id == user?.name, orElse: () {
          print('학생 목록에서도 찾지 못함, 기본 데이터 생성: $studentId');
          return StudentProgress(
              id: studentId,
              name: user?.name ?? '',
              number: 0,
              group: int.tryParse(user?.group ?? '1') ?? 1);
        });
      } catch (e) {
        print('학생 데이터 검색 오류: $e');
        currentStudent = StudentProgress(
            id: studentId,
            name: user?.name ?? '',
            number: 0,
            group: int.tryParse(user?.group ?? '1') ?? 1);
      }
    }

    // 학생의 그룹 찾기
    final group = int.tryParse(user?.group ?? '1') ?? 1;

    // 학생 진행 상태 확인
    print('학생 ${user?.name} (ID: $studentId) 진행 상태:');
    currentStudent.individualProgress.forEach((key, progress) {
      print('- 과제: $key, 완료: ${progress.isCompleted}');
    });

    // 단체줄넘기 허용 여부 확인
    bool canDoGroupTasks = false;
    try {
      canDoGroupTasks = taskProvider.canStartGroupActivities(group);
    } catch (e) {
      print('단체줄넘기 허용 여부 확인 오류: $e');
    }

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
        bool isCompleted = false;
        if (isIndividual) {
          final progress = currentStudent.individualProgress[task.name];
          isCompleted = progress?.isCompleted ?? false;
        } else {
          final progress = currentStudent.groupProgress[task.name];
          isCompleted = progress?.isCompleted ?? false;
        }

        // 디버깅
        print('과제 상태: ${task.name}, 완료=$isCompleted');

        // 과제 활성화 로직 개선
        bool isActive;

        if (isIndividual) {
          // 완료된 과제는 항상 활성화
          if (isCompleted) {
            isActive = true;
          }
          // 레벨 1 과제는 항상 활성화
          else if (task.level == 1) {
            isActive = true;
          }
          // 이미 완료된 과제 수에 기반하여 활성화
          else {
            // 완료된 과제 리스트를 레벨 순으로 정렬
            final completedTasks = currentStudent.individualProgress.entries
                .where((entry) => entry.value.isCompleted)
                .map((entry) {
              final taskModel = individualTasks.firstWhere(
                (t) => t.name == entry.key,
                orElse: () =>
                    TaskModel(id: 0, name: entry.key, count: '', level: 99),
              );
              return taskModel;
            }).toList();

            // 완료된 최고 레벨
            int maxCompletedLevel = 0;
            if (completedTasks.isNotEmpty) {
              // 레벨을 기준으로 내림차순 정렬 (높은 레벨이 먼저)
              completedTasks.sort((a, b) => b.level - a.level);
              maxCompletedLevel = completedTasks.first.level;
            }

            // 완료된 최고 레벨 + 1까지 활성화 (최소 레벨 1은 항상 활성화)
            int activationLevel = maxCompletedLevel + 1;

            print(
                '완료된 과제 수: ${completedTasks.length}, 최고 레벨: $maxCompletedLevel, 활성화 레벨: $activationLevel, 현재 과제 레벨: ${task.level}');
            isActive = task.level <= activationLevel;
          }
        } else {
          // 단체 과제는 조건 충족 시 활성화
          isActive = canDoGroupTasks || isCompleted;
        }

        // 디버깅 정보 출력
        print(
            '과제: ${task.name}, 레벨: ${task.level}, 완료: $isCompleted, 활성화: $isActive');

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

// 수정할 코드
  Future<void> _loadStudentDataFromServer(String studentId) async {
    if (studentId.isEmpty) return;

    try {
      // TaskProvider의 통합 메서드 사용
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      final studentProgress =
          await taskProvider.syncStudentDataFromServer(studentId);

      if (studentProgress != null) {
        print('학생 데이터 로드 성공: ${studentProgress.name}, ${studentProgress.id}');
        print(
            '과제 완료 현황: 개인-${studentProgress.individualProgress.values.where((p) => p.isCompleted).length}개, '
            '단체-${studentProgress.groupProgress.values.where((p) => p.isCompleted).length}개');
      } else {
        print('학생 데이터를 찾을 수 없음: $studentId');
      }

      // 화면 갱신
      setState(() {});
    } catch (e) {
      print('학생 데이터 로드 오류: $e');
      // 에러가 발생해도 UI 갱신
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
