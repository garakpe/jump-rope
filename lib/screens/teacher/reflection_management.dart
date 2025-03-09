// lib/screens/teacher/reflection_management.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/reflection_model.dart';
import '../../models/firebase_models.dart';
import '../../providers/task_provider.dart';
import '../../providers/reflection_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ReflectionManagement extends StatefulWidget {
  final int selectedClassId;

  const ReflectionManagement({
    Key? key,
    required this.selectedClassId,
  }) : super(key: key);

  @override
  _ReflectionManagementState createState() => _ReflectionManagementState();
}

class _ReflectionManagementState extends State<ReflectionManagement> {
  ReflectionSubmission? _selectedSubmission;
  String _statusMessage = '';
  bool _isLoading = false;
  bool _isOffline = false;

  // 제출 현황 캐시
  final Map<String, Map<int, bool>> _submissionCache = {};

  @override
  void initState() {
    super.initState();

    // 학급 선택 시 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.selectedClassId > 0) {
        final taskProvider = Provider.of<TaskProvider>(context, listen: false);
        final reflectionProvider =
            Provider.of<ReflectionProvider>(context, listen: false);

        taskProvider.selectClass(widget.selectedClassId.toString());
        reflectionProvider.selectClassAndWeek(
            widget.selectedClassId.toString(), reflectionProvider.currentWeek);

        // 네트워크 상태 확인
        reflectionProvider.checkNetworkStatus().then((_) {
          setState(() {
            _isOffline = reflectionProvider.isOffline;
          });
        });

        print('ReflectionManagement - 선택된 학급: ${widget.selectedClassId}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedSubmission != null) {
      return _buildSubmissionDetail();
    }

    // 학생 목록 가져오기
    final taskProvider = Provider.of<TaskProvider>(context);
    final reflectionProvider = Provider.of<ReflectionProvider>(context);
    final students = taskProvider.students;
    final currentWeek = reflectionProvider.currentWeek;
    final isOffline = reflectionProvider.isOffline;

    // 학생이 없는 경우 메시지 표시
    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '학급을 선택하고 학생을 추가해주세요',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 헤더 영역
        _buildHeaderCard(currentWeek),
        const SizedBox(height: 16),

        // 오프라인 상태 표시
        if (isOffline)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '오프라인 모드: 일부 기능이 제한되며 최신 데이터를 볼 수 없습니다.',
                    style: TextStyle(color: Colors.orange.shade700),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _syncOfflineData();
                  },
                  child: Text(
                    '동기화 시도',
                    style: TextStyle(color: Colors.orange.shade700),
                  ),
                ),
              ],
            ),
          ),

        // 상태 메시지
        if (_statusMessage.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _statusMessage.contains('성공')
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _statusMessage.contains('성공')
                    ? Colors.green.shade200
                    : Colors.orange.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _statusMessage.contains('성공')
                      ? Icons.check_circle
                      : Icons.info_outline,
                  color: _statusMessage.contains('성공')
                      ? Colors.green.shade600
                      : Colors.orange.shade600,
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

        // 성찰 카드 그리드
        Expanded(
          child: _buildReflectionGrid(currentWeek),
        ),
      ],
    );
  }

  // 헤더 카드
  Widget _buildHeaderCard(int currentWeek) {
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
                Icon(Icons.book, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Text(
                  '성찰 관리',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade700,
                  ),
                ),
              ],
            ),

            // 주차 설정 및 엑셀 다운로드 UI
            Row(
              children: [
                Text(
                  '현재 주차:',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: currentWeek,
                      items: [1, 2, 3].map((week) {
                        return DropdownMenuItem<int>(
                          value: week,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              '$week주차',
                              style: TextStyle(
                                fontWeight: currentWeek == week
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _updateCurrentWeek(value);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.file_download),
                  label: const Text('엑셀 다운로드'),
                  onPressed: _isOffline ? null : _downloadExcel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade100,
                    foregroundColor: Colors.green.shade800,
                    disabledBackgroundColor: Colors.grey.shade200,
                    disabledForegroundColor: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 현재 주차 업데이트 메서드
  void _updateCurrentWeek(int newWeek) async {
    setState(() {
      _isLoading = true;
      _statusMessage = '주차 정보 업데이트 중...';
    });

    try {
      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);
      reflectionProvider.setCurrentWeek(newWeek);

      setState(() {
        _isLoading = false;
        _statusMessage =
            '성공: $newWeek주차로 설정되었습니다. 이제 학생들은 $newWeek주차 성찰까지 작성할 수 있습니다.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '오류: 주차 정보 업데이트 실패 - $e';
      });
    }
  }

  // 오프라인 데이터 동기화
  void _syncOfflineData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '오프라인 데이터 동기화 중...';
    });

    try {
      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);
      await reflectionProvider.syncOfflineData();

      setState(() {
        _isLoading = false;
        _isOffline = reflectionProvider.isOffline;
        _statusMessage = '동기화 성공: 최신 데이터가 로드되었습니다.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '동기화 오류: $e';
      });
    }
  }

  // 엑셀 다운로드
  void _downloadExcel() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '엑셀 파일 생성 중...';
    });

    try {
      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);
      final url = await reflectionProvider.generateExcelDownloadUrl();

      setState(() {
        _isLoading = false;
        _statusMessage = '엑셀 파일이 생성되었습니다. 다운로드 링크가 브라우저에서 열립니다.';
      });

      // URL 열기 (개발 중에는 print만, 실제 앱에서는 URL 론처 사용)
      print('다운로드 URL: $url');

      // 다음 코드 사용시 url_launcher 패키지 필요
      /* 
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        setState(() {
          _statusMessage = 'URL을 열 수 없습니다: $url';
        });
      }
      */
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '엑셀 생성 오류: $e';
      });
    }
  }

  // 성찰 그리드
  Widget _buildReflectionGrid(int currentWeek) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 3, // 3주차 성찰
      itemBuilder: (context, index) {
        final weekNum = index + 1;
        final bool isActive = weekNum <= currentWeek;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // 카드 헤더
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isActive
                        ? [Colors.amber.shade500, Colors.orange.shade400]
                        : [Colors.grey.shade300, Colors.grey.shade400],
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
                    Text(
                      '$weekNum주차 성찰',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    // 활성화 상태 아이콘
                    Icon(
                      isActive ? Icons.lock_open : Icons.lock,
                      size: 16,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),

              // 학생 목록
              Expanded(
                child: isActive
                    ? _buildStudentList(weekNum)
                    : _buildInactiveWeekView(weekNum),
              ),
            ],
          ),
        );
      },
    );
  }

  // 비활성화된 주차 표시
  Widget _buildInactiveWeekView(int weekNum) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 32,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            '비활성화됨',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '현재 주차를 변경하여 활성화',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 학생 목록 빌드
  Widget _buildStudentList(int weekNum) {
    final students = Provider.of<TaskProvider>(context).students;
    final reflectionProvider = Provider.of<ReflectionProvider>(context);
    final submissionStatus = reflectionProvider.submissionStatus;

    return ListView.builder(
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        final reflectionId =
            reflectionCards.firstWhere((r) => r.week == weekNum).id;

        // 제출 상태 확인 (로컬 캐시 기반)
        final hasSubmitted = submissionStatus[student.id] ?? false;

        return ListTile(
          onTap: () {
            if (hasSubmitted) {
              _loadStudentSubmission(student.id, reflectionId, weekNum);
            } else if (!_isOffline) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('제출된 성찰이 없습니다.')),
              );
            }
          },
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${student.group}모둠',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade800,
                fontSize: 12,
              ),
            ),
          ),
          title: Text(
            '${student.number}번 ${student.name}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: hasSubmitted ? Colors.green.shade100 : Colors.red.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              hasSubmitted ? '제출완료' : '미제출',
              style: TextStyle(
                color:
                    hasSubmitted ? Colors.green.shade800 : Colors.red.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }

  // 학생 제출물 로드
  void _loadStudentSubmission(
      String studentId, int reflectionId, int week) async {
    setState(() {
      _isLoading = true;
      _statusMessage = '성찰 데이터 로드 중...';
    });

    try {
      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);
      final submission =
          await reflectionProvider.getSubmission(studentId, reflectionId);

      if (submission != null) {
        setState(() {
          _selectedSubmission = submission;
          _isLoading = false;
          _statusMessage = '';
        });
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = '성찰 데이터를 찾을 수 없습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '데이터 로드 오류: $e';
      });
    }
  }

  // 제출된 성찰 상세 보기
  Widget _buildSubmissionDetail() {
    if (_selectedSubmission == null) return const SizedBox.shrink();

    final reflectionId = _selectedSubmission!.reflectionId;
    final reflection = reflectionCards.firstWhere(
      (r) => r.id == reflectionId,
      orElse: () => reflectionCards.first,
    );

    return Column(
      children: [
        // 헤더 영역
        Card(
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
                    Icon(Icons.book, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedSubmission!.studentName}의 ${reflection.week}주차 성찰',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('돌아가기'),
                  onPressed: () {
                    setState(() {
                      _selectedSubmission = null;
                    });
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.amber.shade50,
                    foregroundColor: Colors.amber.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 질문 및 답변 목록
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: reflection.questions.length,
            itemBuilder: (context, index) {
              final question = reflection.questions[index];
              final answer = _selectedSubmission!.answers[question] ?? '';

              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 질문 헤더
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Text(
                        '${index + 1}. $question',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),

                    // 답변 영역
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: TextEditingController(text: answer),
                        maxLines: 4,
                        readOnly: true, // 읽기 전용
                        decoration: InputDecoration(
                          hintText: '학생 답변...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.amber.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.amber.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.amber.shade400),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
