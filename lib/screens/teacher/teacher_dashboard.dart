// lib/screens/teacher/teacher_dashboard.dart
import 'package:flutter/material.dart';
import '../../providers/reflection_provider.dart';
import '../../providers/student_provider.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart' as studentprovider;
import 'group_management.dart';
import 'progress_management.dart';
import 'reflection_management.dart';
import 'student_upload_screen.dart';
import '../../providers/task_provider.dart';

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
      appBar: AppBar(
        title: Row(
          children: [
            const Text('줄넘기 학습 관리 (교사용)'),
            if (isOffline) _buildOfflineIndicator(),
          ],
        ),
        actions: [
          if (isOffline) _buildSyncButton(taskProvider),
          _buildUserInfo(authProvider),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 상단 헤더 영역
            _buildHeaderCard(isOffline),
            const SizedBox(height: 16),

            // 탭바
            _buildTabBar(),
            const SizedBox(height: 16),

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

  // 오프라인 상태 표시 위젯
  Widget _buildOfflineIndicator() {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 14, color: Colors.orange.shade800),
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
    );
  }

  // 동기화 버튼
  Widget _buildSyncButton(TaskProvider taskProvider) {
    return IconButton(
      icon: const Icon(Icons.sync),
      tooltip: '데이터 동기화',
      onPressed: () {
        taskProvider.syncData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('데이터 동기화 중...')),
        );
      },
    );
  }

  // 사용자 정보 및 로그아웃 버튼
  Widget _buildUserInfo(AuthProvider authProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            '${authProvider.userInfo?.name} 선생님',
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
    );
  }

  // 탭바 위젯
  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.blue.shade700,
        unselectedLabelColor: Colors.grey.shade700,
        tabs: const [
          Tab(
            icon: Icon(Icons.group),
            text: '모둠 관리',
          ),
          Tab(
            icon: Icon(Icons.school),
            text: '학습 현황',
          ),
          Tab(
            icon: Icon(Icons.book),
            text: '성찰 관리',
          ),
        ],
      ),
    );
  }

  // 헤더 카드 위젯
  Widget _buildHeaderCard(bool isOffline) {
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

                // 오프라인 상태 표시
                if (isOffline) _buildOfflineWarning(),
              ],
            ),
            Row(
              children: [
                // 학생 일괄 등록 버튼
                _buildStudentUploadButton(),
                const SizedBox(width: 16),
                // 학급 선택 드롭다운
                _buildClassSelector(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 오프라인 경고 위젯
  Widget _buildOfflineWarning() {
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
          const SizedBox(width: 8),
          Text(
            '오프라인 모드',
            style: TextStyle(
              color: Colors.orange.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _showSyncDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('동기화 관리'),
          ),
        ],
      ),
    );
  }

  // 학생 일괄 등록 버튼
  Widget _buildStudentUploadButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.upload_file),
      label: const Text('학생 일괄 등록'),
      onPressed: () => _navigateToStudentUpload(),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade500,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
      ),
    );
  }

  // 학생 일괄 등록 화면으로 이동
  void _navigateToStudentUpload() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StudentUploadScreen(),
      ),
    ).then((result) {
      if (result != null &&
          result is Map &&
          result.containsKey('refreshClass')) {
        final classNumString = result['refreshClass'].toString();
        if (classNumString.isNotEmpty) {
          final classNumInt = int.tryParse(classNumString);
          if (classNumInt != null) {
            _updateSelectedClass(classNumInt, classNumString);
          }
        }
      }
    });
  }

  // 선택된 학급 업데이트
  void _updateSelectedClass(int classId, String classNumString) {
    setState(() {
      _selectedClassId = classId;
    });

    // 데이터 로드
    Provider.of<StudentProvider>(context, listen: false)
        .setSelectedClass(classId.toString().padLeft(2, '0')); // 두 자리 문자열로 변환
    Provider.of<TaskProvider>(context, listen: false)
        .selectClass(classId.toString().padLeft(2, '0')); // 두 자리 문자열로 변환

    // 첫 번째 탭(모둠관리)으로 이동
    _tabController.animateTo(0);

    // 디버깅용 로그
    print('학급 데이터 리프레시: ${classId.toString().padLeft(2, '0')}반');
  }

  // 학급 선택 드롭다운
  Widget _buildClassSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedClassId == 0 ? null : _selectedClassId,
          hint: const Text('학급 선택'),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
          borderRadius: BorderRadius.circular(16),
          items: _classes.map((cls) {
            return DropdownMenuItem<int>(
              value: cls['id'],
              child: Text(cls['name']),
            );
          }).toList(),
          onChanged: _onClassSelected,
        ),
      ),
    );
  }

  // 학급 선택 처리
  void _onClassSelected(int? value) {
    if (value != null) {
      setState(() {
        _selectedClassId = value;
      });

      // 디버깅 정보 출력
      print('교사 대시보드 - 학급 선택: $_selectedClassId');

      // 학급 정보 업데이트
      final classNumString = value.toString().padLeft(2, '0'); // 두 자리 문자열로 변환
      Provider.of<studentprovider.StudentProvider>(context, listen: false)
          .setSelectedClass(classNumString);
      Provider.of<TaskProvider>(context, listen: false)
          .selectClass(classNumString);
      Provider.of<ReflectionProvider>(context, listen: false)
          .selectClassAndReflectionType(classNumString, 1);

      // 첫 번째 탭으로 리셋
      _tabController.animateTo(0);

      print('학급 선택됨: $classNumString (교사 대시보드)');
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
            const SizedBox(width: 8),
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
            SizedBox(height: 16),
            Text(
              '옵션:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('1. 지금 동기화: 데이터 동기화를 즉시 시도합니다.'),
            Text('2. 로컬 상태 유지: 변경사항을 로컬에 계속 저장하고 나중에 동기화합니다.'),
            SizedBox(height: 16),
            Text(
              '주의: 동기화 전까지 변경사항은 다른 기기에서 볼 수 없습니다.',
              style: TextStyle(color: Colors.red, fontSize: 12),
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
            onPressed: () => _syncData(taskProvider),
          ),
        ],
      ),
    );
  }

  // 데이터 동기화 함수
  void _syncData(TaskProvider taskProvider) {
    Navigator.pop(context);

    // 동기화 시도 및 결과 알림
    taskProvider.syncData().then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('데이터 동기화가 완료되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('동기화 오류: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  // 학급 미선택 상태 화면
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
          const SizedBox(height: 16),
          Text(
            '상단에서 학급을 선택해주세요',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          // 학생 등록 안내 추가
          Container(
            padding: const EdgeInsets.all(16),
            width: 400,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: const Column(
              children: [
                Text(
                  '시작하기',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '1. 상단의 "학생 일괄 등록" 버튼을 클릭해 엑셀 파일로 학생 명단을 업로드하세요.\n'
                  '2. 학급을 선택하여 학생들의 현황을 확인하고 관리할 수 있습니다.\n'
                  '3. 모둠 관리 탭에서 학생들의 모둠을 구성하세요.',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
