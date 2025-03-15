// lib/widgets/ui/custom_reflection_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../models/firebase_models.dart'; // ReflectionStatus 가져오기

class CustomReflectionCard extends StatelessWidget {
  final int index;
  final String question;
  final TextEditingController controller;
  final bool readOnly;
  final double? rating; // 선생님 평가 점수 (옵션)
  final Function(double)? onRatingChanged; // 평가 변경 콜백 (옵션)

  const CustomReflectionCard({
    Key? key,
    required this.index,
    required this.question,
    required this.controller,
    this.readOnly = false,
    this.rating,
    this.onRatingChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: readOnly ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 질문 헤더
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade100, Colors.amber.shade200],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.shade300.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade800,
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
          ),

          // 답변 영역
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (readOnly)
                  // 읽기 전용일 때는 TextField 대신 Container로 표시
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      controller.text.isEmpty ? '답변 없음' : controller.text,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: controller.text.isEmpty
                            ? Colors.grey.shade500
                            : Colors.black87,
                      ),
                    ),
                  )
                else
                  // 편집 가능할 때는 TextField 사용
                  TextField(
                    controller: controller,
                    maxLines: 4,
                    minLines: 3,
                    decoration: InputDecoration(
                      hintText: '여기에 답변을 입력하세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.amber.shade300, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),

                // 교사 평가 영역 (선택적)
                if (readOnly && onRatingChanged != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '평가 점수:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildRatingBar(),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 평가 점수 위젯
  Widget _buildRatingBar() {
    const maxRating = 5.0;
    final currentRating = rating ?? 0;

    return Row(
      children: [
        Expanded(
          child: Slider(
            value: currentRating,
            max: maxRating,
            divisions: 10,
            label: currentRating.toStringAsFixed(1),
            activeColor: Colors.amber.shade600,
            inactiveColor: Colors.grey.shade300,
            onChanged: onRatingChanged,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            currentRating.toStringAsFixed(1),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade800,
            ),
          ),
        ),
      ],
    );
  }
}

class ReflectionStatusBadge extends StatelessWidget {
  final ReflectionStatus status;
  final double size;

  const ReflectionStatusBadge({
    Key? key,
    required this.status,
    this.size = 1.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 상태에 따른 스타일 변경
    final (color, text, icon) = _getStatusInfo();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12 * size,
        vertical: 6 * size,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16 * size),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16 * size, color: color),
          SizedBox(width: 6 * size),
          Text(
            text,
            style: TextStyle(
              fontSize: 12 * size,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // 상태별 정보 반환
  (Color, String, IconData) _getStatusInfo() {
    switch (status) {
      case ReflectionStatus.notSubmitted:
        return (Colors.grey, '미제출', Icons.error_outline);
      case ReflectionStatus.submitted:
        return (Colors.blue, '제출완료', Icons.check_circle_outline);
      case ReflectionStatus.rejected:
        return (Colors.orange, '반려됨', Icons.warning_amber_rounded);
      case ReflectionStatus.accepted:
        return (Colors.green, '승인됨', Icons.verified_outlined);
    }
  }
}

// 새로운 위젯: 성찰 보고서 카드 (목록 표시용)
class ReflectionCardItem extends StatelessWidget {
  final String title;
  final ReflectionStatus status;
  final String studentName;
  final String studentId;
  final int groupNumber;
  final DateTime submittedDate;
  final VoidCallback onTap;

  const ReflectionCardItem({
    Key? key,
    required this.title,
    required this.status,
    required this.studentName,
    required this.studentId,
    required this.groupNumber,
    required this.submittedDate,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final (statusColor, bgColor) = _getStatusColors();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: status == ReflectionStatus.submitted
              ? Colors.blue.shade200
              : status == ReflectionStatus.rejected
                  ? Colors.orange.shade200
                  : status == ReflectionStatus.accepted
                      ? Colors.green.shade200
                      : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [bgColor.withOpacity(0.1), bgColor.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  ReflectionStatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: bgColor.withOpacity(0.3),
                    child: Text(
                      studentName.isNotEmpty ? studentName[0] : '?',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _buildInfoChip(
                            '학번: $studentId',
                            Icons.badge_outlined,
                            Colors.grey.shade700,
                          ),
                          const SizedBox(width: 8),
                          _buildInfoChip(
                            '$groupNumber모둠',
                            Icons.group,
                            Colors.grey.shade700,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(submittedDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 상태에 따른 색상 정보 반환
  (Color, Color) _getStatusColors() {
    switch (status) {
      case ReflectionStatus.notSubmitted:
        return (Colors.grey.shade600, Colors.grey);
      case ReflectionStatus.submitted:
        return (Colors.blue.shade700, Colors.blue);
      case ReflectionStatus.rejected:
        return (Colors.orange.shade700, Colors.orange);
      case ReflectionStatus.accepted:
        return (Colors.green.shade700, Colors.green);
    }
  }

  // 정보 칩 위젯
  Widget _buildInfoChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // 날짜 포맷팅
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateDay = DateTime(date.year, date.month, date.day);

    if (dateDay == today) {
      return '오늘 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (dateDay == yesterday) {
      return '어제 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}
