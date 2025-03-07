import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentUploadScreen extends StatefulWidget {
  const StudentUploadScreen({Key? key}) : super(key: key);

  @override
  _StudentUploadScreenState createState() => _StudentUploadScreenState();
}

class _StudentUploadScreenState extends State<StudentUploadScreen> {
  bool _isUploading = false;
  String _statusMessage = '';
  int _uploadedCount = 0;
  int _totalCount = 0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _showTemplate = true; // 템플릿 표시 여부

  // 업로드 결과 추적용 변수
  Map<String, int> _uploadedClassCount = {}; // 학급별 업로드 수 기록

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('학생 일괄 등록'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '엑셀 파일을 업로드하여 학생 데이터를 일괄 등록할 수 있습니다.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              '엑셀 파일은 다음과 같은 형식이어야 합니다:\n'
              '- 첫 번째 열: 학년(1자리)\n'
              '- 두 번째 열: 반(한자리 또는 두자리)\n'
              '- 세 번째 열: 번호(한자리 또는 두자리)\n'
              '- 네 번째 열: 이름',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              '* 학번은 "학년+반(두자리)+번호(두자리)"로 자동 생성됩니다.\n'
              '* 한 자리 반/번호는 자동으로 두 자리로 변환됩니다. (예: 1학년 1반 1번 → 10101)\n'
              '* 학생 로그인 시 학번과 이름을 사용합니다.\n'
              '* 모둠 번호는 학생 등록 후 모둠 관리 화면에서 설정할 수 있습니다.\n'
              '* 엑셀 파일의 반 정보를 그대로 사용하여 학급을 구분합니다.',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue),
            ),
            const SizedBox(height: 16),

            // 엑셀 템플릿 예시
            if (_showTemplate) _buildTemplateExample(),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text('엑셀 파일 선택'),
              onPressed: _isUploading ? null : _pickExcelFile,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 24),
            if (_isUploading)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: _totalCount > 0 ? _uploadedCount / _totalCount : 0,
                  ),
                  const SizedBox(height: 8),
                  Text('진행 상황: $_uploadedCount / $_totalCount'),
                ],
              ),
            const SizedBox(height: 16),
            Text(_statusMessage,
                style: TextStyle(
                  color: _statusMessage.contains('오류')
                      ? Colors.red
                      : _statusMessage.contains('완료')
                          ? Colors.green
                          : Colors.black,
                )),

            // 업로드 완료 후 안내 메시지
            if (_statusMessage.contains('완료'))
              Container(
                margin: const EdgeInsets.only(top: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade600),
                        const SizedBox(width: 8),
                        const Text(
                          '학생 등록 완료!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '다음 단계:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '1. 대시보드에서 학급을 선택하세요.\n'
                      '2. "모둠 관리" 탭을 선택해 학생들의 모둠을 설정하세요.\n'
                      '3. 학생들에게 학번(5자리)과 이름으로 로그인할 수 있다고 안내하세요.',
                    ),

                    // 학급별 업로드 결과 요약 표시
                    if (_uploadedClassCount.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '학급별 업로드 결과:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ..._uploadedClassCount.entries
                                .map((entry) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                          '${entry.key}반: ${entry.value}명'),
                                    ))
                                .toList(),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        child: const Text('대시보드로 돌아가기'),
                        onPressed: () {
                          // 가장 많은 학생이 업로드된 학급을 자동으로 선택
                          String selectedClass = '1'; // 기본값
                          if (_uploadedClassCount.isNotEmpty) {
                            // 가장 많은 학생이 있는 학급 찾기
                            var maxEntry = _uploadedClassCount.entries
                                .reduce((a, b) => a.value > b.value ? a : b);
                            selectedClass = maxEntry.key;
                          }

                          Navigator.of(context)
                              .pop({'refreshClass': selectedClass});
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 업데이트된 템플릿 예시 위젯
  Widget _buildTemplateExample() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '엑셀 형식 예시',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showTemplate = false;
                  });
                },
                child: const Text('닫기'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(
                    label: Text('학년',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('반',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('번호',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('이름',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('생성될 학번',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: const [
                DataRow(cells: [
                  DataCell(Text('1')),
                  DataCell(Text('1')),
                  DataCell(Text('1')),
                  DataCell(Text('김코드')),
                  DataCell(Text('10101')),
                ]),
                DataRow(cells: [
                  DataCell(Text('1')),
                  DataCell(Text('1')),
                  DataCell(Text('2')),
                  DataCell(Text('이영희')),
                  DataCell(Text('10102')),
                ]),
                DataRow(cells: [
                  DataCell(Text('1')),
                  DataCell(Text('2')),
                  DataCell(Text('1')),
                  DataCell(Text('박지민')),
                  DataCell(Text('10201')),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickExcelFile() async {
    try {
      setState(() {
        _isUploading = true;
        _statusMessage = '파일 선택 중...';
        _uploadedClassCount = {}; // 업로드 결과 초기화
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null) {
        setState(() {
          _statusMessage = '파일을 처리 중입니다...';
        });

        Uint8List? fileBytes = result.files.first.bytes;

        if (fileBytes != null) {
          await _processExcelFile(fileBytes);
        } else {
          setState(() {
            _isUploading = false;
            _statusMessage = '파일을 읽을 수 없습니다.';
          });
        }
      } else {
        // 사용자가 파일 선택을 취소한 경우
        setState(() {
          _isUploading = false;
          _statusMessage = '파일 선택이 취소되었습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _statusMessage = '오류가 발생했습니다: $e';
      });
    }
  }

  Future<void> _processExcelFile(Uint8List bytes) async {
    try {
      // 엑셀 파일 파싱
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables.keys.first;
      final rows = excel.tables[sheet]?.rows;

      if (rows == null || rows.isEmpty) {
        setState(() {
          _isUploading = false;
          _statusMessage = '엑셀 파일에 데이터가 없습니다.';
        });
        return;
      }

      // 첫 번째 행은 헤더로 간주
      final dataRows = rows.length > 1 ? rows.sublist(1) : [];
      _totalCount = dataRows.length;
      _uploadedCount = 0;

      if (_totalCount == 0) {
        setState(() {
          _isUploading = false;
          _statusMessage = '등록할 학생 데이터가 없습니다.';
        });
        return;
      }

      // 중복 학번 확인을 위한 Set
      Set<String> existingStudentIds = {};

      try {
        // 기존 학생 ID 확인
        QuerySnapshot querySnapshot =
            await _firestore.collection('students').get();

        for (var doc in querySnapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          if (data['studentId'] != null) {
            existingStudentIds.add(data['studentId'].toString());
          }
        }
      } catch (e) {
        print('Firestore 연결 오류, 로컬 모드로 진행: $e');
        // Firestore 접근 실패해도 계속 진행
      }

      // 학생 데이터 수집
      List<Map<String, dynamic>> studentsData = [];

      for (var row in dataRows) {
        if (row.length < 4) continue; // 데이터가 충분하지 않은 행 건너뛰기

        // 셀 데이터 추출
        final grade = row[0]?.value?.toString() ?? '';

        // 반과 번호를 문자열로 가져온 후 정수로 변환하고 다시 두 자리 문자열로 포맷팅
        String rawClassNum = row[1]?.value?.toString() ?? '';
        String rawStudentNum = row[2]?.value?.toString() ?? '';

        // 숫자가 아닌 경우나 빈 문자열 처리
        int? classNumInt = int.tryParse(rawClassNum);
        int? studentNumInt = int.tryParse(rawStudentNum);

        if (classNumInt == null || studentNumInt == null) {
          continue; // 숫자로 변환할 수 없는 데이터는 건너뛰기
        }

        // 두 자리 문자열로 변환 (예: 1 -> "01")
        final formattedClassNum = classNumInt.toString().padLeft(2, '0');
        final studentNum = studentNumInt.toString().padLeft(2, '0');
        final name = row[3]?.value?.toString() ?? '';

        // 학년 + 반 + 번호로 학번 생성 (5자리)
        final studentId = '$grade$formattedClassNum$studentNum';
        final className = grade; // 학년을 className으로 사용

        if (grade.isEmpty || name.isEmpty) {
          continue; // 필수 데이터 없는 행 건너뛰기
        }

        // 데이터 유효성 검증
        if (!_validateStudentData(grade, formattedClassNum, studentNum, name)) {
          continue;
        }

        // 중복 확인
        if (existingStudentIds.contains(studentId)) {
          continue; // 이미 존재하는 학번은 건너뛰기
        }

        // 중요: 여기서 엑셀의 반 정보(classNumInt)를 classNum 필드에 그대로 사용
        final classNum = classNumInt.toString();

        studentsData.add({
          'studentId': studentId,
          'name': name,
          'grade': grade,
          'classNum': classNum, // 엑셀에서 가져온 반 정보 사용
          'studentNum': studentNum,
          'className': className,
          'group': 1, // 기본 모둠 번호 1로 설정
          'individualTasks': {}, // 초기 개인 과제 진행 상황 (빈 맵)
          'groupTasks': {}, // 초기 단체 과제 진행 상황 (빈 맵)
          'attendance': true, // 기본 출석 상태
          'createdAt': FieldValue.serverTimestamp(), // 생성 시간
        });

        // 학급별 카운트 증가
        _uploadedClassCount[classNum] =
            (_uploadedClassCount[classNum] ?? 0) + 1;
      }

      _totalCount = studentsData.length;
      _uploadedCount = 0;

      if (_totalCount == 0) {
        setState(() {
          _isUploading = false;
          _statusMessage = '등록할 유효한 학생 데이터가 없습니다.';
        });
        return;
      }

      setState(() {
        _statusMessage = '학생 데이터를 등록 중입니다...';
      });

      try {
        // Firestore에 데이터 업로드
        final batch = _firestore.batch();
        const int batchSize = 450; // 안전을 위해 500보다 작게 설정

        for (int i = 0; i < studentsData.length; i += batchSize) {
          int end = (i + batchSize < studentsData.length)
              ? i + batchSize
              : studentsData.length;

          for (int j = i; j < end; j++) {
            final studentData = studentsData[j];
            DocumentReference docRef =
                _firestore.collection('students').doc(); // 자동 ID 생성

            batch.set(docRef, studentData);
            _uploadedCount++;

            // UI 업데이트를 위해 상태 갱신
            if (j % 10 == 0) {
              // 10개마다 UI 갱신
              setState(() {});
            }
          }

          await batch.commit();
        }

        setState(() {
          _isUploading = false;
          _statusMessage = '업로드 완료: $_uploadedCount명의 학생 데이터가 등록되었습니다.';
        });
      } catch (e) {
        print('Firestore 배치 업로드 오류: $e');

        setState(() {
          _isUploading = false;
          _statusMessage = 'Firestore 저장 실패: $e - 나중에 다시 시도해주세요.';
        });
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _statusMessage = '데이터 처리 중 오류가 발생했습니다: $e';
      });
    }
  }

  // 데이터 유효성 검증
  bool _validateStudentData(
      String grade, String classNum, String studentNum, String name) {
    // 학년, 이름이 비어있지 않은지 확인
    if (grade.isEmpty || name.isEmpty) {
      return false;
    }

    // 학년 형식 검증 (1~9 사이의 숫자)
    if (!RegExp(r'^[1-9]$').hasMatch(grade)) {
      return false;
    }

    // 반과 번호는 이미 두 자리로 패딩되어 변환되었으므로 01~99 범위 체크
    int? classNumInt = int.tryParse(classNum);
    int? studentNumInt = int.tryParse(studentNum);

    if (classNumInt == null ||
        classNumInt < 1 ||
        classNumInt > 99 ||
        studentNumInt == null ||
        studentNumInt < 1 ||
        studentNumInt > 99) {
      return false;
    }

    // 이름 길이 확인 (너무 짧거나 긴 경우 제외)
    if (name.length < 2 || name.length > 10) {
      return false;
    }

    return true;
  }
}
