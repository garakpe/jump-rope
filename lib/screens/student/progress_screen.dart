// lib/screens/student/progress_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../models/ui_models.dart';
import '../../providers/auth_provider.dart';

// 현재 학생의 진도 정보 찾기 (일관된 방식으로)
StudentProgress getCurrentStudent(TaskProvider taskProvider, String studentId) {
  if (studentId.isEmpty) {
    return StudentProgress(id: '', name: '로그인 필요', number: 0, group: 0);
  }

  // 캐시에서 먼저 확인
  final cachedStudent = taskProvider.getStudentFromCache(studentId);
  if (cachedStudent != null) {
    print('캐시에서 학생 데이터 찾음: $studentId, 이름: ${cachedStudent.name}');
    return cachedStudent;
  }

  // 목록에서 검색
  try {
    final student = taskProvider.students.firstWhere(
      (s) => s.id == studentId,
      orElse: () => throw Exception('학생을 찾을 수 없음'),
    );

    print('학생 목록에서 데이터 찾음: $studentId');
    return student;
  } catch (e) {
    print('학생 검색 실패: $e, 기본 데이터 사용');
    return StudentProgress(
        id: studentId, name: '데이터 로딩 중', number: 0, group: 0);
  }
}

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final currentWeek = taskProvider.currentWeek;
    final stampCount = taskProvider.stampCount;
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
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                final user = authProvider.userInfo;
                final studentId = user?.studentId ?? '';
                if (studentId.isNotEmpty) {
                  taskProvider.refreshStudentData(studentId);
                }
              },
            ),
          ],
        ),
      );
    }

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
                          '확인 도장 개수: $stampCount개',
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
                  child: buildProgressTable(context, students),
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

// 변경 후
  Widget buildProgressTable(
      BuildContext context, List<StudentProgress> students) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userInfo;

    // 내 학생 ID 및 그룹 정보 찾기
    final myId = user?.studentId ?? '';
    final group = int.tryParse(user?.group ?? '1') ?? 1;

    print('진도표 구성: 학생ID=$myId, 그룹=$group, 전체 학생 수=${students.length}');

    // 1. 캐시된 그룹원 먼저 확인
    var groupStudents = students.where((s) => s.group == group).toList();

    // 2. 그룹원이 없을 경우 서버에서 다시 로드 시도
    if (groupStudents.isEmpty && myId.isNotEmpty && !taskProvider.isLoading) {
      print('모둠원 데이터가 없어서 서버에서 로드 시도: 그룹=$group, 학생ID=$myId');

      // 현재 학생 로드 + 모둠원 함께 로드 (백그라운드 실행)
      Future.microtask(() {
        taskProvider.syncStudentDataFromServer(myId).then((_) {
          if (group > 0) {
            taskProvider.loadGroupMembers(group, user?.className ?? '1');
          }
        });
      });

      // 임시로 현재 학생 정보만 표시
      final myInfo = taskProvider.getStudentFromCache(myId);
      if (myInfo != null) {
        groupStudents = [myInfo];
        print('현재는 로그인한 학생만 표시: ${myInfo.name}');
      } else {
        groupStudents = [
          StudentProgress(
            id: myId,
            name: user?.name ?? '데이터 로딩 중...',
            number: 0,
            group: group,
          )
        ];
      }
    }

    // 3. 다른 로그인 사용자의 학생 데이터가 섞여 있는지 확인하고 필터링
    if (groupStudents.isNotEmpty && myId.isNotEmpty) {
      // 자신과 같은 그룹에 속한 학생만 필터링
      groupStudents = groupStudents.where((s) => s.group == group).toList();
      print('필터링 후 모둠원 수: ${groupStudents.length}명 (그룹 $group)');
    }

    // 이름순 정렬
    groupStudents.sort((a, b) => a.name.compareTo(b.name));

    // 모둠 자격 조건 확인 (단체줄넘기 활성화 여부)
    bool canDoGroupTask = false;
    try {
      canDoGroupTask = taskProvider.canStartGroupActivities(group);
    } catch (e) {
      print('단체줄넘기 자격 확인 오류: $e');
    }

    // 데이터가 없는 경우 안내 메시지
    if (groupStudents.isEmpty) {
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
                  taskProvider.refreshStudentData(myId);
                }
              },
            ),
          ],
        ),
      );
    }

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
        ...individualTasks.map((task) => DataColumn(
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
        ...groupTasks.map((task) => DataColumn(
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
      rows: groupStudents.map((student) {
        // 현재 학생 강조 표시
        final isCurrentStudent = student.id == myId;

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
            ...individualTasks.map((task) {
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
            ...groupTasks.map((task) {
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
