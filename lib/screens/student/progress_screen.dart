// lib/screens/student/progress_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../models/ui_models.dart';
import '../../providers/auth_provider.dart';

// 현재 학생의 진도 정보 찾기 - 간결화
StudentProgress getCurrentStudent(TaskProvider taskProvider, String studentId) {
  if (studentId.isEmpty) {
    return StudentProgress(
        id: studentId, name: '', number: 0, group: 0, studentId: studentId);
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
          group: 0,
          studentId: studentId),
    );
  } catch (e) {
    return StudentProgress(
        id: studentId,
        name: '데이터 로딩 중',
        number: 0,
        group: 0,
        studentId: studentId);
  }
}

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({Key? key}) : super(key: key);

  @override
  _ProgressScreenState createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  List<StudentProgress> _filteredStudents = [];
  int _moduStamps = 0;

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

    // 에러 메시지가 있고 학생 데이터가 없는 경우 오류 UI 표시
    if (error.isNotEmpty && students.isEmpty) {
      return _buildErrorView(error, authProvider);
    }

    // 내 정보 가져오기
    final myId = user?.studentId ?? '';
    final myGroup = int.tryParse(user?.group ?? '1') ?? 1;

    // 필터링된 학생 목록 업데이트
    _updateFilteredStudents(students, myId, myGroup, user?.studentId ?? '');

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 주차 및 도장 개수 표시 카드
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '($currentWeek주차) 모둠 줄넘기 진도표',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '모둠 도장 개수: $_moduStamps개',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 진도표 카드
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 1200, // 넓은 테이블을 위한 고정 너비
                  child: _filteredStudents.isEmpty
                      ? _buildNoDataView(myId)
                      : buildProgressTable(context, _filteredStudents),
                ),
              ),
            ),
          ),

          // 안내문 카드
          Card(
            elevation: 1,
            margin: const EdgeInsets.only(top: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '* 개인줄넘기 영역은 단계적으로 진도 나갈 것',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '* 확인도장 20개 이상일 경우부터 단체줄넘기 시도할 수 있음',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '* 단체줄넘기 영역은 선택적으로 시도할 수 있음',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 에러 표시 위젯
  Widget _buildErrorView(String error, AuthProvider authProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.orange),
          const SizedBox(height: 16),
          Text(
            '데이터 불러오기 오류',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
            onPressed: () {
              // 데이터 새로고침 시도
              final user = authProvider.userInfo;
              final studentId = user?.studentId ?? '';
              if (studentId.isNotEmpty) {
                Provider.of<TaskProvider>(context, listen: false)
                    .refreshStudentData(studentId);
              }
            },
          ),
        ],
      ),
    );
  }

  // 데이터 없음 표시 위젯
  Widget _buildNoDataView(String myId) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_off, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '모둠원 데이터를 찾을 수 없습니다',
            style: TextStyle(color: Colors.grey.shade600),
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
          ),
        ],
      ),
    );
  }

  // 필터링된 학생 목록 업데이트
  void _updateFilteredStudents(List<StudentProgress> students, String myId,
      int myGroup, String myStudentId) {
    // 같은 모둠, 같은 반 학생 필터링
    _filteredStudents = students.where((s) {
      // 1. 자기 자신은 항상 포함
      if (s.id == myId || s.studentId == myId) return true;

      // 2. 같은 그룹 학생 필터링
      final sameGroup = s.group == myGroup;
      if (!sameGroup) return false;

      // 3. 같은 반 여부 확인
      final otherStudentId = s.studentId;

      if (myStudentId.isNotEmpty && otherStudentId.isNotEmpty) {
        if (myStudentId.length >= 3 && otherStudentId.length >= 3) {
          final myPrefix = myStudentId.substring(0, 3);
          final otherPrefix = otherStudentId.substring(0, 3);
          return myPrefix == otherPrefix;
        }
      }

      return false;
    }).toList();

    // 이름순 정렬
    _filteredStudents.sort((a, b) => a.name.compareTo(b.name));

    // 모둠 도장 수 계산
    _calculateModuStamps();
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

  Widget buildProgressTable(
      BuildContext context, List<StudentProgress> students) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userInfo;

    // 내 학생 ID
    final myId = user?.studentId ?? '';

    return DataTable(
      columnSpacing: 10,
      headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
      border: TableBorder.all(
        color: Colors.grey.shade300,
        width: 1,
      ),
      columns: [
        const DataColumn(
          label: Text(
            '모둠원',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ...TaskModel.getIndividualTasks().map((task) => DataColumn(
              label: Expanded(
                child: Text(
                  '${task.name}\n${task.count}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )),
        ...TaskModel.getGroupTasks().map((task) => DataColumn(
              label: Expanded(
                child: Text(
                  '${task.name}\n${task.count}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )),
      ],
      rows: students.map((student) {
        // 현재 학생 강조 표시
        final isCurrentStudent =
            student.id == myId || student.studentId == myId;

        return DataRow(
          color: isCurrentStudent
              ? WidgetStateProperty.all(Colors.blue.shade50)
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
            ...TaskModel.getIndividualTasks().map((task) {
              final progress = student.individualProgress[task.name];
              final isCompleted = progress?.isCompleted ?? false;
              final completionDate = progress?.completedDate;

              return DataCell(
                Container(
                  color: isCompleted ? Colors.blue.shade50 : null,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isCompleted)
                        const Icon(Icons.check_circle, color: Colors.blue),
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
                ),
              );
            }),
            ...TaskModel.getGroupTasks().map((task) {
              final progress = student.groupProgress[task.name];
              final isCompleted = progress?.isCompleted ?? false;
              final completionDate = progress?.completedDate;

              return DataCell(
                Container(
                  color: isCompleted ? Colors.green.shade50 : null,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isCompleted)
                        const Icon(Icons.check_circle, color: Colors.green),
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
                ),
              );
            }),
          ],
        );
      }).toList(),
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

      return '$y/$m/$d';
    } catch (e) {
      // 날짜 형식이 아닌 경우 원본 그대로 반환 (최대 10자)
      return dateString.length > 10 ? dateString.substring(0, 10) : dateString;
    }
  }
}
