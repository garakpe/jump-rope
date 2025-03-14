class ReflectionModel {
  final int id;
  final String title;
  final List<String> questions;
  final Map<String, String> answers;

  ReflectionModel({
    required this.id,
    required this.title,
    required this.questions,
    this.answers = const {},
  });
}

// 성찰 질문 데이터
final List<ReflectionModel> reflectionCards = [
  ReflectionModel(
    id: 1,
    title: "초기 성찰",
    questions: [
      "이번 체육 수업에서 나의 학습 목표는 무엇인가요?",
      "줄넘기를 잘하기 위해서 어떤 노력이 필요할까요?",
      "나의 현재 줄넘기 실력은 어느 정도라고 생각하나요?",
      "모둠 활동에서 나의 역할은 무엇인가요?"
    ],
  ),
  ReflectionModel(
    id: 2,
    title: "중기 성찰",
    questions: [
      "지금까지 배운 것 중 가장 어려웠던 동작은 무엇인가요?",
      "어려움을 극복하기 위해 어떤 노력을 했나요?",
      "모둠 활동에서 잘된 점과 개선할 점은 무엇인가요?",
      "남은 수업에서 도전하고 싶은 것은 무엇인가요?"
    ],
  ),
  ReflectionModel(
    id: 3,
    title: "최종 성찰",
    questions: [
      "이번 줄넘기 수업을 통해 무엇을 배웠나요?",
      "처음과 비교하여 나의 실력이 얼마나 향상되었나요?",
      "모둠 활동이 나의 학습에 어떤 도움이 되었나요?",
      "앞으로도 줄넘기를 계속하고 싶은가요? 그 이유는?"
    ],
  ),
];
