// lib/screens/student/reflection_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/reflection_provider.dart';
import '../../models/reflection_model.dart';

class ReflectionScreen extends StatefulWidget {
  const ReflectionScreen({Key? key}) : super(key: key);

  @override
  _ReflectionScreenState createState() => _ReflectionScreenState();
}

class _ReflectionScreenState extends State<ReflectionScreen> {
  int _selectedWeek = 1;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    // 컨트롤러 해제
    _controllers.forEach((key, controller) {
      controller.dispose();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 성찰 카드 헤더
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
                  Text(
                    '줄넘기 성찰 작성',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: DropdownButton<int>(
                      value: _selectedWeek,
                      dropdownColor: Colors.white,
                      underline: Container(),
                      items: [1, 2, 3].map((week) {
                        return DropdownMenuItem<int>(
                          value: week,
                          child: Text(
                            '$week주차',
                            style: TextStyle(
                              color: Colors.amber.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedWeek = value;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 성찰 내용 - 준비 중 메시지
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.book_outlined,
                        size: 64, color: Colors.amber.shade300),
                    const SizedBox(height: 16),
                    Text(
                      '성찰 작성 기능 준비 중...',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('성찰 작성 기능은 곧 업데이트될 예정입니다',
                        style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade100,
                        foregroundColor: Colors.amber.shade700,
                        disabledBackgroundColor: Colors.grey.shade200,
                        disabledForegroundColor: Colors.grey.shade500,
                      ), // 비활성화
                      child: const Text('성찰 저장하기'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
