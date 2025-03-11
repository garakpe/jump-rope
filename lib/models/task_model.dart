// 리팩토링된 task_model.dart
class TaskModel {
  final int id;
  final String name;
  final String count;
  final int level;
  final bool isIndividual;
  final String description;

  const TaskModel({
    required this.id,
    required this.name,
    required this.count,
    required this.level,
    this.isIndividual = true,
    this.description = '',
  });

  // 개인 줄넘기 과제 목록
  static List<TaskModel> getIndividualTasks() => const [
        TaskModel(
            id: 1,
            name: "양발모아 뛰기",
            count: "50회",
            level: 1,
            description:
                "두 발을 모아 제자리에서 뛰는 기본 동작입니다. 착지 시 무릎을 살짝 굽혀 충격을 흡수하세요."),
        TaskModel(
            id: 2,
            name: "구보로 뛰기",
            count: "50회",
            level: 2,
            description: "제자리에서 구보 동작으로 뛰기를 합니다. 팔 동작을 자연스럽게 하면서 뛰어주세요."),
        TaskModel(
            id: 3,
            name: "십자뛰기",
            count: "20회",
            level: 3,
            description: "앞, 뒤, 좌, 우로 십자 모양을 그리며 뛰는 동작입니다. 방향 전환을 부드럽게 하세요."),
        TaskModel(
            id: 4,
            name: "가위바위보 뛰기",
            count: "30회",
            level: 4,
            description: "가위바위보 동작을 하면서 뛰기를 합니다. 리듬감 있게 동작을 연결하세요."),
        TaskModel(
            id: 5,
            name: "엇걸었다 풀어 뛰기",
            count: "10회",
            level: 5,
            description: "줄을 엇갈리게 넘었다가 풀어서 뛰는 고급 동작입니다. 손목 동작이 중요합니다."),
        TaskModel(
            id: 6,
            name: "이중뛰기",
            count: "10회",
            level: 6,
            description: "한 번 뛰어오를 때 줄을 두 번 돌리는 동작입니다. 높이 점프하여 시간을 확보하세요."),
      ];

  // 단체 줄넘기 과제 목록
  static List<TaskModel> getGroupTasks() => const [
        TaskModel(
            id: 1,
            name: "2인 맞서서 뛰기",
            count: "20회",
            level: 1,
            isIndividual: false,
            description: "두 사람이 마주보고 서서 한 줄을 함께 넘습니다. 호흡을 맞추는 것이 중요합니다."),
        TaskModel(
            id: 2,
            name: "엇갈아 2인뛰기",
            count: "20회",
            level: 2,
            isIndividual: false,
            description: "두 사람이 번갈아가며 뛰는 동작입니다. 타이밍을 잘 맞춰야 합니다."),
        TaskModel(
            id: 3,
            name: "배웅통과하기",
            count: "4회",
            level: 3,
            isIndividual: false,
            description: "돌아가는 줄을 통과하여 뛰는 동작입니다. 줄의 속도와 타이밍을 잘 맞추세요."),
        TaskModel(
            id: 4,
            name: "1인 4도약 연속뛰기",
            count: "2회",
            level: 4,
            isIndividual: false,
            description:
                "한 사람이 4번 연속으로 도약하며 줄넘기를 하는 동작입니다. 리듬감과 균형 유지가 중요합니다."),
        TaskModel(
            id: 5,
            name: "단체줄넘기",
            count: "30회",
            level: 5,
            isIndividual: false,
            description: "여러 명이 함께 줄을 넘는 단체 활동입니다. 일정한 간격을 유지하세요."),
        TaskModel(
            id: 6,
            name: "긴 줄 연속 8자 뛰기",
            count: "40회",
            level: 6,
            isIndividual: false,
            description:
                "긴 줄을 8자 모양으로 돌리며 여러 명이 연속으로 뛰는 고급 동작입니다. 팀워크와 타이밍이 매우 중요합니다."),
      ];
}
