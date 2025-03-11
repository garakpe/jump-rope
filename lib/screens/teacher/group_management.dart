import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/student_provider.dart';
import '../../models/firebase_models.dart';

class GroupManagement extends StatefulWidget {
  final int selectedClassId;

  const GroupManagement({
    Key? key,
    required this.selectedClassId,
  }) : super(key: key);

  @override
  _GroupManagementState createState() => _GroupManagementState();
}

class _GroupManagementState extends State<GroupManagement> {
  bool _isEditMode = false;
  String _viewMode = 'group'; // 'group' 또는 'roster', 기본값은 'group'
  int _totalGroups = 4; // 기본 모둠 수
  bool _isProcessing = false; // 처리 중 상태
  String _statusMessage = ''; // 상태 메시지

  // 모둠 변경을 추적하기 위한 임시 저장소
  final Map<String, int> _pendingGroupChanges = {};

  @override
  void initState() {
    super.initState();

    // 학급 변경 시 학생 데이터 불러오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.selectedClassId > 0) {
        final studentProvider =
            Provider.of<StudentProvider>(context, listen: false);
        final selectedClass = widget.selectedClassId.toString();
        print('GroupManagement - 학급 $selectedClass 선택됨');
        studentProvider.setSelectedClass(selectedClass);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final studentProvider = Provider.of<StudentProvider>(context);
    final students = studentProvider.students;
    final isLoading = studentProvider.isLoading;

    // 디버깅용 로그 추가
    print('GroupManagement.build - 학생 수: ${students.length}, 로딩 중: $isLoading');
    if (students.isNotEmpty) {
      print(
          '첫 번째 학생 정보: ID=${students[0].id}, 이름=${students[0].name}, 학번=${students[0].studentId}');
    }

    // 현재 모둠 목록
    final groupList = studentProvider.getGroupList();
    if (groupList.isNotEmpty && _totalGroups < groupList.length) {
      _totalGroups = groupList.length;
    }

    return Column(
      children: [
        // 헤더 영역
        _buildHeaderCard(),
        const SizedBox(height: 16),

        // 상태 메시지
        if (_statusMessage.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            decoration: BoxDecoration(
              color:
                  _statusMessage.contains('실패') || _statusMessage.contains('오류')
                      ? Colors.red.shade50
                      : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _statusMessage.contains('실패') ||
                        _statusMessage.contains('오류')
                    ? Colors.red.shade200
                    : Colors.green.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _statusMessage.contains('실패') || _statusMessage.contains('오류')
                      ? Icons.error
                      : Icons.check_circle,
                  color: _statusMessage.contains('실패') ||
                          _statusMessage.contains('오류')
                      ? Colors.red
                      : Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_statusMessage),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    setState(() {
                      _statusMessage = '';
                    });
                  },
                ),
              ],
            ),
          ),

        // 로딩 인디케이터
        if (isLoading)
          Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text('학생 데이터를 불러오는 중...',
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),

        // 학생 수가 0인 경우 추가 디버깅 정보
        if (!isLoading && students.isEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.yellow.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.yellow.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      '데이터가 없습니다',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('선택한 학급: ${widget.selectedClassId}반'),
                Text('Provider 학급: ${studentProvider.selectedClass}'),
                Text('현재 모둠 목록: $groupList'),
                const SizedBox(height: 8),
                const Text(
                  '학생 데이터를 찾을 수 없습니다. 다음 사항을 확인해 보세요:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text('1. 학생 일괄 등록이 완료되었는지 확인해 주세요.'),
                const Text('2. 학생 등록 시 "업로드할 학급 번호"를 올바르게 입력했는지 확인해 주세요.'),
                const Text('3. 학급 드롭다운에서 올바른 학급을 선택했는지 확인해 주세요.'),
              ],
            ),
          ),

        // 모둠 또는 명렬표 보기
        if (!isLoading)
          Expanded(
            child: _viewMode == 'group'
                ? _buildGroupView(students)
                : _buildRosterView(students),
          ),
      ],
    );
  }

  Widget _buildHeaderCard() {
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
                Icon(Icons.people, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  '${widget.selectedClassId}반 모둠 관리',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            _isEditMode
                ? Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.swap_horiz),
                        label:
                            Text(_viewMode == 'group' ? '명렬표로 보기' : '모둠별로 보기'),
                        onPressed: () {
                          setState(() {
                            _viewMode =
                                _viewMode == 'group' ? 'roster' : 'group';
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade100,
                          foregroundColor: Colors.indigo.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('저장하기'),
                        onPressed: _isProcessing ? null : _saveGroupChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ],
                  )
                : ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('모둠 편집'),
                    onPressed: () {
                      setState(() {
                        _isEditMode = true;
                        // 편집 모드 진입 시 변경 내역 초기화
                        _pendingGroupChanges.clear();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupView(List<FirebaseStudentModel> students) {
    // 디버깅용 로그 추가
    print('_buildGroupView 호출됨 - 학생 수: ${students.length}');

    // 그룹 목록 생성
    final groups = <int>{};
    for (var student in students) {
      // 변경 예정인 모둠이 있으면 그 모둠을 사용, 없으면 현재 모둠 사용
      int displayGroup = _pendingGroupChanges[student.id] ?? student.group;
      groups.add(displayGroup);
    }

    // 그룹이 없는 경우 기본 메시지 표시
    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '학급을 선택하고 학생을 추가해주세요',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text('학생 일괄 등록'),
              onPressed: () {
                Navigator.pushNamed(context, '/student_upload');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final groupNum = groups.elementAt(index);

        // 현재 표시할 모둠에 속한 학생들 (변경 예정인 모둠 반영)
        final groupStudents = students.where((s) {
          int studentGroup = _pendingGroupChanges[s.id] ?? s.group;
          return studentGroup == groupNum;
        }).toList();

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // 그룹 헤더
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.indigo.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.group,
                            color: Colors.blue.shade600, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '$groupNum모둠',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${groupStudents.length}명',
                      style: TextStyle(
                        color: Colors.blue.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // 학생 목록
              Expanded(
                child: ListView.builder(
                  itemCount: groupStudents.length,
                  itemBuilder: (context, studentIndex) {
                    final student = groupStudents[studentIndex];

                    return ListTile(
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              student.studentId,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            student.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      trailing: _isEditMode
                          ? DropdownButton<int>(
                              value: _pendingGroupChanges[student.id] ??
                                  student.group,
                              items: List.generate(_totalGroups, (i) => i + 1)
                                  .map((g) => DropdownMenuItem<int>(
                                        value: g,
                                        child: Text('$g모둠'),
                                      ))
                                  .toList(),
                              onChanged: (newGroup) {
                                if (newGroup != null) {
                                  setState(() {
                                    // 변경 사항 임시 저장
                                    _pendingGroupChanges[student.id] = newGroup;
                                  });

                                  // 상태 메시지 표시
                                  setState(() {
                                    _statusMessage =
                                        '${student.name}의 모둠을 $newGroup모둠으로 변경했습니다. 저장 버튼을 눌러 반영하세요.';
                                  });
                                }
                              },
                            )
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRosterView(List<FirebaseStudentModel> students) {
    // 학생이 없는 경우 기본 메시지 표시
    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_alt_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '학급을 선택하고 학생을 추가해주세요',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    // 학생 정렬 (학번 순)
    final sortedStudents = List<FirebaseStudentModel>.from(students);
    sortedStudents.sort((a, b) => a.studentId.compareTo(b.studentId));
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade500, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '학생 명렬표',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        '모둠 수:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 50,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _totalGroups,
                            dropdownColor: Colors.white,
                            items: List.generate(8, (i) => i + 1)
                                .map((num) => DropdownMenuItem<int>(
                                      value: num,
                                      child: Text(
                                        num.toString(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ))
                                .toList(),
                            onChanged: _isEditMode
                                ? (value) {
                                    if (value != null) {
                                      setState(() {
                                        _totalGroups = value;
                                      });
                                    }
                                  }
                                : null, // 편집 모드에서만 활성화
                            icon: const Icon(Icons.arrow_drop_down,
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 명렬표 필터 및 정렬 옵션
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Text('정렬: '),
                TextButton.icon(
                  icon: const Icon(Icons.sort_by_alpha),
                  label: const Text('이름순'),
                  onPressed: () {
                    // 이름순 정렬
                    // 실제 구현 시 Provider에 정렬 옵션 추가
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.format_list_numbered),
                  label: const Text('학번순'),
                  onPressed: () {
                    // 학번순 정렬
                    // 실제 구현 시 Provider에 정렬 옵션 추가
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          // 명렬표
          Expanded(
            child: ListView.builder(
              itemCount: sortedStudents.length,
              itemBuilder: (context, index) {
                final student = sortedStudents[index];

                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Center(
                      child: Text(
                        student.studentId.length > 2
                            ? student.studentId
                                .substring(student.studentId.length - 2)
                            : student.studentId, // 학번 마지막 2자리
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    student.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '학번: ${student.studentId}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  trailing: _isEditMode
                      ? DropdownButton<int>(
                          value:
                              _pendingGroupChanges[student.id] ?? student.group,
                          items: List.generate(_totalGroups, (i) => i + 1)
                              .map((g) => DropdownMenuItem<int>(
                                    value: g,
                                    child: Text('$g모둠'),
                                  ))
                              .toList(),
                          onChanged: (newGroup) {
                            if (newGroup != null) {
                              setState(() {
                                // 변경 사항 임시 저장
                                _pendingGroupChanges[student.id] = newGroup;
                              });

                              // 상태 메시지 표시
                              setState(() {
                                _statusMessage =
                                    '${student.name}의 모둠을 $newGroup모둠으로 변경했습니다. 저장 버튼을 눌러 반영하세요.';
                              });
                            }
                          },
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${student.group}모둠',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 모둠 변경 사항 저장
  Future<void> _saveGroupChanges() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = '모둠 정보를 저장 중입니다...';
    });

    try {
      final studentProvider =
          Provider.of<StudentProvider>(context, listen: false);

      // 변경 사항이 있는 학생들만 업데이트
      if (_pendingGroupChanges.isNotEmpty) {
        // 학생 ID 목록과 새 모둠 번호 맵을 전달하여 일괄 업데이트
        await studentProvider
            .updateGroupsForMultipleStudents(_pendingGroupChanges);
      }

      setState(() {
        _isProcessing = false;
        _isEditMode = false;
        _pendingGroupChanges.clear(); // 변경 내역 초기화
        _statusMessage = '모둠 구성이 성공적으로 저장되었습니다.';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = '모둠 저장 실패: $e';
      });
    }
  }
}
