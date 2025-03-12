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
    _selectedClass = className;
    _isLoading = true;
    _error = '';
    _students = [];
    notifyListeners();

    if (className.isNotEmpty) {
      subscribeToClass(className);
    }
  }

  // 학급별 학생 목록 구독
  void subscribeToClass(String className) {
    _isLoading = true;
    notifyListeners();

    try {
      // 'classNum' 필드로 학생 구독
      _firestore
          .collection('students')
          .where('classNum', isEqualTo: className)
          .orderBy('studentId')
          .snapshots()
          .listen(
        (snapshot) {
          _students = snapshot.docs
              .map((doc) => FirebaseStudentModel.fromFirestore(doc))
              .toList();

          // classNum으로 학생을 찾지 못하면 className으로 시도
          if (_students.isEmpty) {
            _tryClassNameQuery(className);
          } else {
            _isLoading = false;
            notifyListeners();
          }
        },
        onError: _handleError,
      );
    } catch (e) {
      _handleError(e);
    }
  }

  // 'className' 필드로 학생 조회 시도
  void _tryClassNameQuery(String className) {
    _firestore
        .collection('students')
        .where('className', isEqualTo: className)
        .orderBy('studentId')
        .get()
        .then(
      (snapshot) {
        _students = snapshot.docs
            .map((doc) => FirebaseStudentModel.fromFirestore(doc))
            .toList();
        _isLoading = false;
        notifyListeners();
      },
      onError: _handleError,
    );
  }

  // 에러 처리 공통 함수
  void _handleError(dynamic e) {
    _isLoading = false;
    _error = e.toString();
    notifyListeners();
  }

  // 학생 문서 ID 조회 헬퍼 함수
  Future<String?> _getStudentDocId(String studentId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('students')
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      return querySnapshot.docs.isEmpty ? null : querySnapshot.docs.first.id;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // 학생 모둠 업데이트
  Future<void> updateStudentGroup(String studentId, int newGroup) async {
    try {
      String? docId = await _getStudentDocId(studentId);
      if (docId == null) throw Exception("학생을 찾을 수 없습니다");

      await _firestore
          .collection('students')
          .doc(docId)
          .update({'group': newGroup});

      // 로컬 목록 업데이트
      _updateLocalStudent(
          studentId, (student) => student.copyWith(group: newGroup));
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // 로컬 학생 데이터 업데이트 헬퍼 함수
  void _updateLocalStudent(String studentId,
      FirebaseStudentModel Function(FirebaseStudentModel) update) {
    final index = _students.indexWhere((s) => s.studentId == studentId);
    if (index >= 0) {
      final newList = List<FirebaseStudentModel>.from(_students);
      newList[index] = update(_students[index]);
      _students = newList;
      notifyListeners();
    }
  }

  // 여러 학생의 모둠을 동시에 변경 (Map 사용)
  Future<void> updateGroupsForMultipleStudents(
      Map<String, int> studentGroupMap) async {
    if (studentGroupMap.isEmpty) return;

    try {
      _isLoading = true;
      notifyListeners();

      // Firestore 일괄 처리
      final batch = _firestore.batch();
      final updatedStudents = <FirebaseStudentModel>[];

      for (var entry in studentGroupMap.entries) {
        final studentId = entry.key; // 문서 ID
        final newGroup = entry.value;

        // 배치에 업데이트 추가
        DocumentReference docRef =
            _firestore.collection('students').doc(studentId);
        batch.update(docRef, {'group': newGroup});

        // 로컬 업데이트를 위해 수정된 학생 정보 찾기
        final index = _students.indexWhere((s) => s.id == studentId);
        if (index >= 0) {
          updatedStudents.add(_students[index].copyWith(group: newGroup));
        }
      }

      // 배치 커밋
      await batch.commit();

      // 로컬 학생 목록 업데이트
      _updateMultipleStudents(updatedStudents);
    } catch (e) {
      _error = "모둠 업데이트 실패: $e";
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 여러 학생 업데이트 헬퍼 함수
  void _updateMultipleStudents(List<FirebaseStudentModel> updatedStudents) {
    final newList = List<FirebaseStudentModel>.from(_students);
    for (var updatedStudent in updatedStudents) {
      final index = newList.indexWhere((s) => s.id == updatedStudent.id);
      if (index >= 0) {
        newList[index] = updatedStudent;
      }
    }
    _students = newList;
  }

  // 모둠 일괄 변경 (여러 학생의 모둠을 한번에 변경)
  Future<void> updateGroupForStudents(
      List<String> studentIds, int newGroup) async {
    if (studentIds.isEmpty) return;

    try {
      _isLoading = true;
      notifyListeners();

      // 트랜잭션으로 일괄 처리
      final batch = _firestore.batch();
      final updatedStudents = <FirebaseStudentModel>[];

      for (final studentId in studentIds) {
        // 학생 문서 ID 찾기
        final docId = await _getStudentDocId(studentId);
        if (docId != null) {
          batch.update(_firestore.collection('students').doc(docId),
              {'group': newGroup});

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
      _updateMultipleStudents(updatedStudents);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 출석 상태 업데이트
  Future<void> updateAttendance(String studentId, bool isPresent) async {
    try {
      // 학생 문서 ID 찾기
      final docId = await _getStudentDocId(studentId);
      if (docId == null) throw Exception("학생을 찾을 수 없습니다");

      await _firestore
          .collection('students')
          .doc(docId)
          .update({'attendance': isPresent});

      // 로컬 목록 업데이트
      _updateLocalStudent(
          studentId, (student) => student.copyWith(attendance: isPresent));
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // 학생 삭제
  Future<void> deleteStudent(String studentId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // 학생 문서 ID 찾기
      final docId = await _getStudentDocId(studentId);
      if (docId == null) throw Exception("학생을 찾을 수 없습니다");

      await _firestore.collection('students').doc(docId).delete();

      // 로컬 목록 업데이트
      _students = _students.where((s) => s.studentId != studentId).toList();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 모둠별 학생 목록 가져오기
  List<FirebaseStudentModel> getStudentsByGroup(int groupId) {
    return _students.where((student) => student.group == groupId).toList();
  }

  // 총 모둠 수 계산
  int getTotalGroups() {
    if (_students.isEmpty) return 0;
    return getGroupList().length;
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
