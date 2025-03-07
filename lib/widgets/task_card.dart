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
    // 색상 구성
    Color cardColor;
    Color iconColor;
    IconData cardIcon;
    String statusText;

    if (isCompleted) {
      // 이미 완료한 과제
      cardColor = Colors.amber.shade50;
      iconColor = Colors.amber.shade600;
      cardIcon = Icons.check_circle;
      statusText = '성공';
    } else if (isActive) {
      // 도전 가능한 과제
      cardColor =
          task.isIndividual ? Colors.blue.shade50 : Colors.green.shade50;
      iconColor =
          task.isIndividual ? Colors.blue.shade600 : Colors.green.shade600;
      cardIcon = task.isIndividual ? Icons.person : Icons.people;
      statusText = '도전 가능';
    } else {
      // 도전 불가능한 과제
      cardColor = Colors.grey.shade100;
      iconColor = Colors.grey.shade500;
      cardIcon = Icons.lock;
      statusText = task.isIndividual ? '이전 단계 완료 필요' : '개인줄넘기 완료 필요';
    }

    return GestureDetector(
      onTap: onTap, // 클릭 시 동작은 상위 위젯에서 결정
      child: Opacity(
        opacity: isActive || isCompleted ? 1.0 : 0.7, // 비활성화 시 약간 흐리게
        child: Card(
          elevation: isActive || isCompleted ? 2 : 1,
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
                    : isActive
                        ? (task.isIndividual
                            ? Colors.blue.shade300
                            : Colors.green.shade300)
                        : Colors.grey.shade300,
                width: isActive || isCompleted ? 2 : 1,
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
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          cardIcon,
                          color: iconColor,
                          size: 36,
                        ),
                        if (!isActive && !isCompleted)
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade400),
                              ),
                              child: Icon(
                                Icons.lock,
                                color: Colors.grey.shade600,
                                size: 16,
                              ),
                            ),
                          ),
                      ],
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
                      color: isActive || isCompleted
                          ? Colors.black87
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 횟수
                  Text(
                    '목표: ${task.count}',
                    style: TextStyle(
                      color: isActive || isCompleted
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
                          : isActive
                              ? (task.isIndividual
                                  ? Colors.blue.shade50
                                  : Colors.green.shade50)
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCompleted
                            ? Colors.amber.shade200
                            : isActive
                                ? (task.isIndividual
                                    ? Colors.blue.shade200
                                    : Colors.green.shade200)
                                : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: isCompleted
                            ? Colors.amber.shade700
                            : isActive
                                ? (task.isIndividual
                                    ? Colors.blue.shade700
                                    : Colors.green.shade700)
                                : Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // 레벨 표시
                  if (task.isIndividual)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${task.level}단계',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
