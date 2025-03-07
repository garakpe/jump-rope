// lib/widgets/task_card.dart
import 'package:flutter/material.dart';
import '../models/task_model.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final bool isActive;
  final bool isCompleted;
  final VoidCallback? onTap;
  final int currentLevel;

  const TaskCard({
    Key? key,
    required this.task,
    this.isActive = true,
    this.isCompleted = false,
    this.onTap,
    required this.currentLevel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 카드 색상 상태 결정
    final bool isAvailable = task.level <= currentLevel;

    // 색상 구성
    Color cardColor;
    Color iconColor;

    if (isCompleted) {
      // 성공한 과제 - 황금색 계열
      cardColor = Colors.amber.shade50;
      iconColor = Colors.amber.shade600;
    } else if (isAvailable) {
      // 도전 가능한 과제 - 파란색/초록색 계열
      cardColor =
          task.isIndividual ? Colors.blue.shade50 : Colors.green.shade50;
      iconColor =
          task.isIndividual ? Colors.blue.shade600 : Colors.green.shade600;
    } else {
      // 도전 불가능한 과제 - 회색/검은색 계열
      cardColor = Colors.grey.shade100;
      iconColor = Colors.grey.shade700;
    }

    return GestureDetector(
      onTap: isAvailable ? onTap : null,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            border: Border.all(
              color: isCompleted
                  ? Colors.amber.shade300
                  : isAvailable
                      ? (task.isIndividual
                          ? Colors.blue.shade300
                          : Colors.green.shade300)
                      : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 아이콘 영역
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: cardColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check_circle
                        : (task.level > currentLevel
                            ? Icons.lock
                            : (task.isIndividual
                                ? Icons.person
                                : Icons.people)),
                    color: iconColor,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),

                // 과제명
                Text(
                  task.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isAvailable ? Colors.black87 : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 8),

                // 횟수
                Text(
                  '목표: ${task.count}',
                  style: TextStyle(
                    color: isAvailable
                        ? Colors.grey.shade700
                        : Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),

                // 상태 표시
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.amber.shade50
                        : isAvailable
                            ? (task.isIndividual
                                ? Colors.blue.shade50
                                : Colors.green.shade50)
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isCompleted
                        ? '성공'
                        : isAvailable
                            ? '도전 가능'
                            : '잠김',
                    style: TextStyle(
                      color: isCompleted
                          ? Colors.amber.shade700
                          : isAvailable
                              ? (task.isIndividual
                                  ? Colors.blue.shade700
                                  : Colors.green.shade700)
                              : Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
