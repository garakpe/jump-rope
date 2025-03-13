// lib/widgets/ui/custom_reflection_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../models/firebase_models.dart'; // ReflectionStatus 가져오기

class ReflectionEditableAnswerCard extends StatelessWidget {
  final int index;
  final String question;
  final TextEditingController controller;
  final bool readOnly;

  const ReflectionEditableAnswerCard({
    Key? key,
    required this.index,
    required this.question,
    required this.controller,
    this.readOnly = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 질문 번호와 내용
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemOrange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.systemOrange,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    question,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 답변 입력 필드
            TextField(
              controller: controller,
              maxLines: 4,
              minLines: 3,
              decoration: InputDecoration(
                hintText: '답변을 입력하세요...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.amber.shade300),
                ),
              ),
              readOnly: readOnly,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: readOnly ? Colors.grey : Colors.black87,
              ),
            ),

            // 읽기 전용 안내 메시지
            if (readOnly)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '* 승인된 성찰은 수정할 수 없습니다.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
