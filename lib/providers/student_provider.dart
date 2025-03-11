// lib/providers/student_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/firebase_models.dart';

class StudentProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<FirebaseStudentModel> _students = [];
  String _selectedClass = '';
  bool _isLoading = false;
  String _error = '';

  List<FirebaseStudentModel> get students => _students;
  String get selectedClass => _selectedClass;
  bool get isLoading => _isLoading;
  String get error => _error;

  // 현재 선택된 학급 설정
  void setSelectedClass(String className) {
    // 중요: 학급 변경 전에 기존 구독을 취소해야 함
    _selectedClass = className;
    _isLoading = true;
    _error = '';
    notifyListeners();

    // 학급이 선택되면 해당 학급의 학생 목록 구독
    if (className.isNotEmpty) {
      print('학급 선택됨: $className - 학생 목록 구독 시작'); // 디버깅용 로그

      // 현재 학생 목록을 비웁니다
      _students = [];
      notifyListeners();

      // 새로운 학급의 학생 목록을 구독합니다
      subscribeToClass(className);
    }
  }

  // 학급별 학생 목록 구독
  void subscribeToClass(String className) {
    _selectedClass = className;
    _isLoading = true;
    notifyListeners();

    try {
      print('Firestore 쿼리 시작: 학급=$className'); // 디버깅용 로그

      // 여러 필드로 검색 시도 (classNum과 className 모두 확인)
      _firestore
          .collection('students')
          .where('classNum', isEqualTo: className)
          .orderBy('studentId')
          .snapshots()
          .listen((snapshot) {
        _students = snapshot.docs
            .map((doc) => FirebaseStudentModel.fromFirestore(doc))
            .toList();

        print('학생 목록 로드됨: ${_students.length}명'); // 디버깅용 로그

        // 만약 학생이 없으면 className으로도 시도해봄
        if (_students.isEmpty) {
          print('classNum으로 학생을 찾지 못함. className으로 시도');
          _firestore
              .collection('students')
              .where('className', isEqualTo: className)
              .orderBy('studentId')
              .get()
              .then((classNameSnapshot) {
            if (classNameSnapshot.docs.isNotEmpty) {
              _students = classNameSnapshot.docs
                  .map((doc) => FirebaseStudentModel.fromFirestore(doc))
                  .toList();
              print('className으로 학생 목록 로드됨: ${_students.length}명');
              _isLoading = false;
              notifyListeners();
            }
          });
        }

        _isLoading = false;
        notifyListeners();
      }, onError: (e) {
        print('Firestore 쿼리 오류: $e'); // 디버깅용 로그
        _isLoading = false;
        _error = e.toString();
        notifyListeners();
      });
    } catch (e) {
      print('subscribeToClass 예외: $e'); // 디버깅용 로그
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  // 학생 모둠 업데이트
  Future<void> updateStudentGroup(String studentId, int newGroup) async {
    try {
      // 학생 문서 ID 찾기
      QuerySnapshot querySnapshot = await _firestore
          .collection('students')
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception("학생을 찾을 수 없습니다");
      }

      // 학생 문서 업데이트
      await _firestore
          .collection('students')
          .doc(querySnapshot.docs.first.id)
          .update({'group': newGroup});

      // 로컬 목록 업데이트
      final index = _students.indexWhere((s) => s.studentId == studentId);
      if (index >= 0) {
        final updatedStudent = _students[index].copyWith(group: newGroup);
        final newList = List<FirebaseStudentModel>.from(_students);
        newList[index] = updatedStudent;
        _students = newList;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // 여러 학생의 모둠을 동시에 변경 (Map 사용)
  Future<void> updateGroupsForMultipleStudents(
      Map<String, int> studentGroupMap) async {
    if (studentGroupMap.isEmpty) return;

    try {
      _isLoading = true;
      notifyListeners();

      // Firestore 일괄 처리를 위한 배치 생성
      final batch = _firestore.batch();
      final updatedStudents = <FirebaseStudentModel>[];

      // 변경 사항 처리
      for (var entry in studentGroupMap.entries) {
        final studentId = entry.key; // 문서 ID
        final newGroup = entry.value;

        // 문서 참조 가져오기
        DocumentReference docRef =
            _firestore.collection('students').doc(studentId);

        // 배치에 업데이트 추가
        batch.update(docRef, {'group': newGroup});

        // 로컬 업데이트를 위해 수정된 학생 정보 찾기
        final index = _students.indexWhere((s) => s.id == studentId);
        if (index >= 0) {
          updatedStudents.add(_students[index].copyWith(group: newGroup));
        }
      }

      // 배치 커밋 (모든 변경 사항을 한 번에 적용)
      await batch.commit();

      // 로컬 학생 목록 업데이트
      final newList = List<FirebaseStudentModel>.from(_students);
      for (var updatedStudent in updatedStudents) {
        final index = newList.indexWhere((s) => s.id == updatedStudent.id);
        if (index >= 0) {
          newList[index] = updatedStudent;
        }
      }

      _students = newList;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = "모둠 업데이트 실패: $e";
      print("모둠 업데이트 오류: $e");
      notifyListeners();
      rethrow;
    }
  }

  // 모둠 일괄 변경 (여러 학생의 모둠을 한번에 변경)
  Future<void> updateGroupForStudents(
      List<String> studentIds, int newGroup) async {
    try {
      _isLoading = true;
      notifyListeners();

      // 트랜잭션으로 일괄 처리
      final batch = _firestore.batch();
      final updatedStudents = <FirebaseStudentModel>[];

      for (final studentId in studentIds) {
        // 학생 문서 ID 찾기
        final QuerySnapshot querySnapshot = await _firestore
            .collection('students')
            .where('studentId', isEqualTo: studentId)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final doc = querySnapshot.docs.first;
          batch.update(doc.reference, {'group': newGroup});

          // 로컬 목록 업데이트 준비
          final index = _students.indexWhere((s) => s.studentId == studentId);
          if (index >= 0) {
            updatedStudents.add(_students[index].copyWith(group: newGroup));
          }
        }
      }

      // 배치 커밋
      await batch.commit();

      // 로컬 목록 업데이트
      final newList = List<FirebaseStudentModel>.from(_students);
      for (final updatedStudent in updatedStudents) {
        final index =
            newList.indexWhere((s) => s.studentId == updatedStudent.studentId);
        if (index >= 0) {
          newList[index] = updatedStudent;
        }
      }

      _students = newList;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // 출석 상태 업데이트
  Future<void> updateAttendance(String studentId, bool isPresent) async {
    try {
      // 학생 문서 ID 찾기
      QuerySnapshot querySnapshot = await _firestore
          .collection('students')
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception("학생을 찾을 수 없습니다");
      }

      // 학생 문서 업데이트
      await _firestore
          .collection('students')
          .doc(querySnapshot.docs.first.id)
          .update({'attendance': isPresent});

      // 로컬 목록 업데이트
      final index = _students.indexWhere((s) => s.studentId == studentId);
      if (index >= 0) {
        final updatedStudent = _students[index].copyWith(attendance: isPresent);
        final newList = List<FirebaseStudentModel>.from(_students);
        newList[index] = updatedStudent;
        _students = newList;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // 모둠별 학생 목록 가져오기
  List<FirebaseStudentModel> getStudentsByGroup(int groupId) {
    return _students.where((student) => student.group == groupId).toList();
  }

  // 총 모둠 수 계산
  int getTotalGroups() {
    if (_students.isEmpty) return 0;

    final groups = <int>{};
    for (var student in _students) {
      groups.add(student.group);
    }

    return groups.length;
  }

  // 모둠별 학생 수 계산
  Map<int, int> getGroupCounts() {
    final counts = <int, int>{};

    for (var student in _students) {
      counts[student.group] = (counts[student.group] ?? 0) + 1;
    }

    return counts;
  }

  // 현재 모둠 목록 가져오기
  List<int> getGroupList() {
    final groups = <int>{};

    for (var student in _students) {
      groups.add(student.group);
    }

    return groups.toList()..sort();
  }

  // 학생 삭제
  Future<void> deleteStudent(String studentId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // 학생 문서 ID 찾기
      QuerySnapshot querySnapshot = await _firestore
          .collection('students')
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception("학생을 찾을 수 없습니다");
      }

      // 학생 문서 삭제
      await _firestore
          .collection('students')
          .doc(querySnapshot.docs.first.id)
          .delete();

      // 로컬 목록 업데이트
      _students = _students.where((s) => s.studentId != studentId).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // 학생 검색
  List<FirebaseStudentModel> searchStudents(String query) {
    if (query.isEmpty) return _students;

    final lowercaseQuery = query.toLowerCase();

    return _students.where((student) {
      return student.name.toLowerCase().contains(lowercaseQuery) ||
          student.studentId.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }
}
