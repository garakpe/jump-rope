import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../models/ui_models.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/ui/custom_ios_style_card_widget.dart';

// 현재 학생의 진도 정보 찾기 - 간결화
StudentProgress getCurrentStudent(TaskProvider taskProvider, String studentId) {
  if (studentId.isEmpty) {
    return StudentProgress(
        id: studentId, name: '', number: 0, group: '0', studentId: studentId);
  }

  // 캐시에서 먼저 확인
  final cachedStudent = taskProvider.getStudentFromCache(studentId);
  if (cachedStudent != null) {
    return cachedStudent;
  }

  // 목록에서 검색
  try {
    return taskProvider.students.firstWhere(
      (s) => s.id == studentId,
      orElse: () => StudentProgress(
          id: studentId,
          name: '데이터 로딩 중',
          number: 0,
          group: '0',
          studentId: studentId),
    );
  } catch (e) {
    return StudentProgress(
        id: studentId,
        name: '데이터 로딩 중',
        number: 0,
        group: '0',
        studentId: studentId);
  }
}

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({Key? key}) : super(key: key);

  @override
  _ProgressScreenState createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  List<StudentProgress> _filteredStudents = [];
  int _moduStamps = 0;
  late TabController _tabController;

  // 한눈에 보기 모드 상태
  bool _overviewMode = false;

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
    final taskProvider = Provider.of<TaskProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userInfo;

    final currentWeek = taskProvider.currentWeek;
    final students = taskProvider.students;
    final isLoading = taskProvider.isLoading;
    final error = taskProvider.error;

    // 로딩 중 표시
    if (isLoading) {
      return _buildLoadingView();
    }

    // 에러 메시지가 있고 학생 데이터가 없는 경우 오류 UI 표시
    if (error.isNotEmpty && students.isEmpty) {
      return _buildErrorView(error, authProvider);
    }

    // 내 정보 가져오기
    final myId = user?.studentId ?? '';
    final myGroup = user?.group ?? '1';

    // 필터링된 학생 목록 업데이트
    _updateFilteredStudents(students, myId, myGroup, user?.studentId ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // iOS 기본 배경색
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 섹션에 "한눈에 보기" 토글 버튼 추가
            _buildHeaderSection(currentWeek),

            // 요약 정보 섹션
            _buildSummarySection(),

            const SizedBox(height: 12),

            // 한눈에 보기 모드인 경우와 아닌 경우 다른 내용 표시
            if (_overviewMode) ...[
              // 한눈에 보기 모드 (표형식 뷰)
              Expanded(
                child: _buildOverviewTable(),
              ),
            ] else ...[
              // 기본 모드 (카드 형식 뷰)
              // 탭 메뉴
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.blue.shade50,
                  ),
                  labelColor: Colors.blue.shade700,
                  unselectedLabelColor: Colors.grey.shade600,
                  tabs: const [
                    Tab(text: '개인 진도'),
                    Tab(text: '모둠 진도'),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 탭 콘텐츠
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // 개인 진도 탭
                    _buildTasksTab(TaskModel.getIndividualTasks(), true),

                    // 모둠 진도 탭
                    _buildTasksTab(TaskModel.getGroupTasks(), false),
                  ],
                ),
              ),
            ],

            // 안내문 카드
            _buildNoteSection(),
          ],
        ),
      ),
    );
  }

  // 로딩 화면 위젯
  Widget _buildLoadingView() {
    return Container(
      color: const Color(0xFFF2F2F7),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              strokeWidth: 2.5,
            ),
            SizedBox(height: 24),
            Text(
              '데이터를 불러오는 중입니다...',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 헤더 섹션
  Widget _buildHeaderSection(int currentWeek) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 제목과 설명
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$currentWeek주차 진도표',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '줄넘기 연습 진도를 확인하세요',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),

          // '한눈에 보기' 토글 버튼
          GestureDetector(
            onTap: () {
              setState(() {
                _overviewMode = !_overviewMode;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: _overviewMode ? Colors.blue.shade100 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.blue.shade300,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _overviewMode ? Icons.view_list : Icons.table_chart,
                    size: 16,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _overviewMode ? '카드 보기' : '한눈에 보기',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 요약 정보 섹션
  Widget _buildSummarySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomCard(
        hasBorder: true,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem(
                  icon: Icons.group,
                  title: '모둠원 수',
                  value: '${_filteredStudents.length}명',
                  color: Colors.blue,
                ),
                Container(height: 40, width: 1, color: Colors.grey.shade200),
                _buildSummaryItem(
                  icon: Icons.star,
                  title: '모둠 도장',
                  value: '$_moduStamps개',
                  color: Colors.orange,
                ),
                Container(height: 40, width: 1, color: Colors.grey.shade200),
                _buildSummaryItem(
                  icon: Icons.trending_up,
                  title: '완료 비율',
                  value: '${_calculateCompletionRate()}%',
                  color: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 요약 아이템 위젯
  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 진도 탭 위젯
  Widget _buildTasksTab(List<TaskModel> tasks, bool isIndividual) {
    return _filteredStudents.isEmpty
        ? _buildNoDataView(
            Provider.of<AuthProvider>(context).userInfo?.studentId ?? '')
        : ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              ...tasks.map((task) => _buildTaskCard(task, isIndividual)),
            ],
          );
  }

  // 과제 카드 위젯
  Widget _buildTaskCard(TaskModel task, bool isIndividual) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userInfo;
    final myId = user?.studentId ?? '';

    // 나의 진도 정보 가져오기
    final myProgress = _filteredStudents.firstWhere(
      (s) => s.id == myId || s.studentId == myId,
      orElse: () => StudentProgress(
          id: myId, name: '', number: 0, group: '', studentId: myId),
    );

    // 이 과제의 진행 상황
    final myTaskProgress = isIndividual
        ? myProgress.individualProgress[task.name]
        : myProgress.groupProgress[task.name];

    final isCompleted = myTaskProgress?.isCompleted ?? false;
    final completionDate = myTaskProgress?.completedDate;

    // 동일 과제에 대한 모둠원들의 진행 상황
    final completedMembers = _filteredStudents.where((student) {
      final progress = isIndividual
          ? student.individualProgress[task.name]
          : student.groupProgress[task.name];
      return progress?.isCompleted ?? false;
    }).toList();

    final completionRatio =
        '${completedMembers.length}/${_filteredStudents.length}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CustomCard(
        hasBorder: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isIndividual
                                ? Colors.blue.shade50
                                : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Level ${task.level}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isIndividual
                                  ? Colors.blue.shade700
                                  : Colors.green.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          task.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.count,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? (isIndividual
                            ? Colors.blue.shade100
                            : Colors.green.shade100)
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      isCompleted ? Icons.check : Icons.hourglass_empty,
                      color: isCompleted
                          ? (isIndividual
                              ? Colors.blue.shade700
                              : Colors.green.shade700)
                          : Colors.grey.shade400,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                task.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.group,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '완료: $completionRatio',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (isCompleted && completionDate != null)
                  Text(
                    '완료일: ${formatDate(completionDate)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
            if (completedMembers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: completedMembers.map((student) {
                  final isMe = student.id == myId || student.studentId == myId;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isMe ? '${student.name} (나)' : student.name,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isMe ? Colors.blue.shade700 : Colors.grey.shade700,
                        fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 안내문 섹션
  Widget _buildNoteSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: CustomCard(
        padding: const EdgeInsets.all(12),
        backgroundColor: const Color(0xFFF2F2F6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNoteItem(
              '개인줄넘기 영역은 단계적으로 진도 나갈 것',
              Icons.info_outline,
            ),
            const SizedBox(height: 8),
            _buildNoteItem(
              '확인도장 20개 이상일 경우부터 단체줄넘기 시도할 수 있음',
              Icons.info_outline,
            ),
            const SizedBox(height: 8),
            _buildNoteItem(
              '단체줄넘기 영역은 선택적으로 시도할 수 있음',
              Icons.info_outline,
            ),
          ],
        ),
      ),
    );
  }

  // 안내 아이템 위젯
  Widget _buildNoteItem(String text, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 14,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  // 에러 표시 위젯
  Widget _buildErrorView(String error, AuthProvider authProvider) {
    return Container(
      color: const Color(0xFFF2F2F7),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: CustomCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Color(0xFFFF3B30), // iOS 오류 색상
                ),
                const SizedBox(height: 16),
                const Text(
                  '데이터 불러오기 오류',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // 데이터 새로고침 시도
                      final user = authProvider.userInfo;
                      final studentId = user?.studentId ?? '';
                      if (studentId.isNotEmpty) {
                        Provider.of<TaskProvider>(context, listen: false)
                            .refreshStudentData(studentId);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('다시 시도'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 데이터 없음 표시 위젯
  Widget _buildNoDataView(String myId) {
    return Container(
      color: const Color(0xFFF2F2F7),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_off,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              '모둠원 데이터를 찾을 수 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('새로고침'),
              onPressed: () {
                // 데이터 새로고침 시도
                if (myId.isNotEmpty) {
                  Provider.of<TaskProvider>(context, listen: false)
                      .refreshStudentData(myId);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 필터링된 학생 목록 업데이트 (개선됨)
  void _updateFilteredStudents(List<StudentProgress> students, String myId,
      String myGroup, String myStudentId) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    // 내 학생 정보 찾기 - 항상 non-nullable StudentProgress 객체 생성
    StudentProgress myStudent;
    try {
      myStudent = students.firstWhere(
        (s) => s.id == myId || s.studentId == myId,
        orElse: () => StudentProgress(
            id: myId,
            name: '',
            number: 0,
            group: myGroup,
            studentId: myStudentId),
      );
    } catch (e) {
      myStudent = StudentProgress(
          id: myId,
          name: '',
          number: 0,
          group: myGroup,
          studentId: myStudentId);
    }

    // 같은 모둠, 같은 반 학생 필터링
    _filteredStudents = students.where((s) {
      // 1. 자기 자신은 항상 포함
      if (s.id == myId || s.studentId == myId) return true;

      // 2. 같은 그룹 학생 필터링
      final sameGroup = s.group == myGroup;
      if (!sameGroup) return false;

      // 3. TaskProvider의 isInSameClass 메서드 활용하여 같은 반 여부 확인
      return taskProvider.isInSameClass(myStudent, s);
    }).toList();

    // 이름순 정렬
    _filteredStudents.sort((a, b) => a.name.compareTo(b.name));

    // 모둠 도장 개수 계산
    _calculateModuStamps();
  }

  // 완료율 계산
  String _calculateCompletionRate() {
    if (_filteredStudents.isEmpty) return "0";

    int totalTasks = 0;
    int completedTasks = 0;

    for (var student in _filteredStudents) {
      // 개인 과제
      totalTasks += student.individualProgress.length;
      completedTasks +=
          student.individualProgress.values.where((p) => p.isCompleted).length;

      // 단체 과제
      totalTasks += student.groupProgress.length;
      completedTasks +=
          student.groupProgress.values.where((p) => p.isCompleted).length;
    }

    if (totalTasks == 0) return "0";

    double rate = (completedTasks / totalTasks) * 100;
    return rate.toStringAsFixed(1);
  }

  // 모둠 도장 개수 계산
  void _calculateModuStamps() {
    _moduStamps = 0;
    for (var student in _filteredStudents) {
      // 개인 과제 완료 개수
      _moduStamps +=
          student.individualProgress.values.where((p) => p.isCompleted).length;

      // 단체 과제 완료 개수
      _moduStamps +=
          student.groupProgress.values.where((p) => p.isCompleted).length;
    }
  }

  // 한눈에 보기 표 위젯 (iOS 스타일의 표)
  Widget _buildOverviewTable() {
    final individualTasks = TaskModel.getIndividualTasks();
    final groupTasks = TaskModel.getGroupTasks();
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userInfo;
    final myId = user?.studentId ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 표 헤더
                Container(
                  color: const Color(0xFFF8F8F8),
                  child: Row(
                    children: [
                      // 학생 이름 셀
                      Container(
                        width: 100,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Colors.grey.shade200),
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: const Text(
                          '모둠원',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),

                      // 개인 과제 헤더
                      Container(
                        color: const Color(0xFFE6F3FF),
                        child: Row(
                          children: individualTasks
                              .map((task) => _buildTableHeaderCell(
                                    task.name,
                                    task.count,
                                    true,
                                  ))
                              .toList(),
                        ),
                      ),

                      // 모둠 과제 헤더
                      Container(
                        color: const Color(0xFFE6FFEE),
                        child: Row(
                          children: groupTasks
                              .map((task) => _buildTableHeaderCell(
                                    task.name,
                                    task.count,
                                    false,
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                // 학생 행
                ..._filteredStudents.map((student) {
                  final isCurrentStudent =
                      student.id == myId || student.studentId == myId;

                  return Container(
                    color:
                        isCurrentStudent ? Colors.blue.shade50 : Colors.white,
                    child: Row(
                      children: [
                        // 학생 이름 셀
                        Container(
                          width: 100,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: Colors.grey.shade200),
                              bottom: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Text(
                            student.name + (isCurrentStudent ? ' (나)' : ''),
                            style: TextStyle(
                              fontWeight: isCurrentStudent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ),

                        // 개인 과제 셀
                        ...individualTasks.map((task) {
                          final progress =
                              student.individualProgress[task.name];
                          return _buildTableCell(progress, true);
                        }),

                        // 모둠 과제 셀
                        ...groupTasks.map((task) {
                          final progress = student.groupProgress[task.name];
                          return _buildTableCell(progress, false);
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 표 헤더 셀 위젯
  Widget _buildTableHeaderCell(String name, String count, bool isIndividual) {
    return Container(
      width: 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade200),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        children: [
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color:
                  isIndividual ? Colors.blue.shade800 : Colors.green.shade800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            count,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // 표 데이터 셀 위젯
  Widget _buildTableCell(TaskProgress? progress, bool isIndividual) {
    final isCompleted = progress?.isCompleted ?? false;
    final completionDate = progress?.completedDate;

    return Container(
      width: 80,
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isCompleted
            ? (isIndividual ? Colors.blue.shade50 : Colors.green.shade50)
            : Colors.transparent,
        border: Border(
          right: BorderSide(color: Colors.grey.shade200),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isCompleted)
            Icon(
              Icons.check_circle,
              color: isIndividual ? Colors.blue : Colors.green,
              size: 20,
            ),
          if (isCompleted && completionDate != null)
            Text(
              formatDate(completionDate),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
        ],
      ),
    );
  }

  // 날짜 포맷팅 함수
  String formatDate(String? dateString) {
    if (dateString == null) return '';

    try {
      final dateTime = DateTime.parse(dateString);

      // 간단한 날짜 포맷 (년/월/일)
      final y = dateTime.year.toString().substring(2); // 년도 뒤 2자리
      final m = dateTime.month.toString().padLeft(2, '0');
      final d = dateTime.day.toString().padLeft(2, '0');

      return '$m월 $d일';
    } catch (e) {
      // 날짜 형식이 아닌 경우 원본 그대로 반환 (최대 10자)
      return dateString.length > 10 ? dateString.substring(0, 10) : dateString;
    }
  }
}
