// lib/screens/student/home_screen.dart
import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../widgets/ui/custom_card.dart';

/// 홈 화면 위젯
///
/// 앱 사용 방법, 평가 방법, 주의사항 등을 표시합니다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(context),
          const SizedBox(height: AppSpacing.md),
          _buildHowToUseCard(context),
          const SizedBox(height: AppSpacing.md),
          _buildEvaluationMethodCard(context),
          const SizedBox(height: AppSpacing.md),
          _buildCautionsCard(context),
          const SizedBox(height: AppSpacing.md),
          _buildTipsCard(context),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  /// 환영 메시지 카드
  Widget _buildWelcomeCard(BuildContext context) {
    return CustomCard(
      header: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.sports_gymnastics,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Text(
            '줄넘기 학습 앱에 오신 것을 환영합니다',
            style: TextStyle(
              fontSize: AppSizes.fontSizeLG,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
      headerColor: AppColors.primary,
      useGradient: true,
      gradientColors: [AppColors.primary, Colors.blue.shade400],
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이 앱은 줄넘기 학습을 돕기 위해 개발되었습니다. 앱을 통해 개인과 단체 줄넘기 과제를 확인하고, 진도를 확인하며, 학습 성찰을 기록할 수 있습니다.',
            style: TextStyle(fontSize: AppSizes.fontSizeMD, height: 1.5),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            '아래의 안내를 참고하여 앱을 효과적으로 활용해 보세요.',
            style: TextStyle(
                fontSize: AppSizes.fontSizeMD,
                fontWeight: FontWeight.bold,
                height: 1.5),
          ),
        ],
      ),
    );
  }

  /// 사용 방법 카드
  Widget _buildHowToUseCard(BuildContext context) {
    return CustomCard(
      header: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.info_outline,
              color: Colors.blue,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Text(
            '앱 사용 방법',
            style: TextStyle(
              fontSize: AppSizes.fontSizeLG,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
      headerColor: Colors.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInstruction(
            number: '1',
            text: '로그인 후, 하단 탭에서 [과제], [진도], [성찰] 화면으로 이동할 수 있습니다.',
          ),
          _buildInstruction(
            number: '2',
            text: '[과제] 탭에서 개인 및 단체 줄넘기 과제를 확인하고, 도전할 수 있습니다.',
          ),
          _buildInstruction(
            number: '3',
            text: '개인줄넘기는 단계별로 진행되며, 이전 단계를 통과해야 다음 단계로 넘어갈 수 있습니다.',
          ),
          _buildInstruction(
            number: '4',
            text: '단체줄넘기(2인 이상)는 모둠의 개인 확인 도장이 모둠원 수 × 5개 이상 있어야 시작할 수 있습니다.',
          ),
          _buildInstruction(
            number: '5',
            text: '과제에 도전할 때는 선생님의 시야를 벗어나지 않는 범위에서 모둠별로 연습하세요.',
          ),
          _buildInstruction(
            number: '6',
            text: '팀원끼리 서로 과제 도전 영상을 촬영하고, 성공 기준을 달성한 영상만 선생님께 확인받으세요.',
          ),
          _buildInstruction(
            number: '7',
            text: '줄넘기 방법이 이해되지 않을 경우, 친구나 선생님에게 도움을 요청할 수 있습니다.',
          ),
          _buildInstruction(
            number: '8',
            text: '[진도] 탭에서 본인과 모둠원들의 과제 진행 상황을 확인할 수 있습니다.',
          ),
          _buildInstruction(
            number: '9',
            text: '[성찰] 탭에서 주차별 학습 성찰을 작성하고 제출할 수 있습니다.',
          ),
        ],
      ),
    );
  }

  /// 평가 방법 카드
  Widget _buildEvaluationMethodCard(BuildContext context) {
    return CustomCard(
      header: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.assessment,
              color: Colors.green,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Text(
            '평가 방법',
            style: TextStyle(
              fontSize: AppSizes.fontSizeLG,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
      headerColor: Colors.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '매 수업시간마다 다음 기준으로 평가합니다:',
            style: TextStyle(
              fontSize: AppSizes.fontSizeMD,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 개인 영역 평가
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person, color: Colors.green),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      '개인 영역',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: AppSizes.fontSizeMD,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                Text('• 개인줄넘기 5단계 이상 달성 시 만점'),
                Text('• 진도 앱에서 확인한 도장 개수로 평가'),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // 모둠 영역 평가
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.group, color: Colors.blue),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      '모둠 영역',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: AppSizes.fontSizeMD,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text('• 단체줄넘기는 모둠원 수 × 5개 이상의 도장이 있어야 시작 가능'),
                const Text('• 모둠 전체 확인 도장이 (모둠원 수 × 11) 이상일 때 만점'),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '예시: 5명 모둠은 5 × 11 = 55개 이상의 도장을 모아야 만점',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 주의사항 카드
  Widget _buildCautionsCard(BuildContext context) {
    return CustomCard(
      header: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.warning_amber,
              color: Colors.orange,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Text(
            '주의사항',
            style: TextStyle(
              fontSize: AppSizes.fontSizeLG,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
      headerColor: Colors.orange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCautionItem(
            icon: Icons.access_time,
            text:
                '줄넘기 연습은 수업시간 동안 계속되어야 합니다. 쉬거나 줄넘기와 무관한 활동을 하는 모둠은 체력 훈련이 부과될 수 있습니다.',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildCautionItem(
            icon: Icons.check_circle,
            text: '진도 확인은 반드시 선생님께 확인받고 도장을 받은 것만 인정됩니다.',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildCautionItem(
            icon: Icons.water_drop,
            text: '수업시간에는 줄넘기만 해야 하며, 화장실, 물 마시러 가는 것 등은 선생님에게 허락을 받아야 합니다.',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildCautionItem(
            icon: Icons.medical_services,
            text:
                '몸이 좋지 않은 학생은 선생님에게 먼저 상태를 알린 후 보건실에 가서 내원증을 끊고 조용히 앉아 모둠 연습을 관람해야 합니다.',
          ),
        ],
      ),
    );
  }

  /// 성공 팁 카드
  Widget _buildTipsCard(BuildContext context) {
    return CustomCard(
      header: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lightbulb,
              color: Colors.purple,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Text(
            '좋은 성적을 얻으려면',
            style: TextStyle(
              fontSize: AppSizes.fontSizeLG,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
      headerColor: Colors.purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTipItem(
            icon: Icons.people,
            text: '나만 잘해서는 절대 팀 점수가 높아질 수 없습니다. 모둠원 모두가 잘해야 좋은 성적을 받을 수 있습니다.',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildTipItem(
            icon: Icons.handshake,
            text: '줄넘기를 못 하는 친구를 도와 진도를 나갈 수 있게 해줘야 좋은 점수를 얻을 수 있습니다.',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildTipItem(
            icon: Icons.timer,
            text: '지금 여러분에게 필요한건... 스피드가 아닌 협동입니다.',
            isHighlighted: true,
          ),
        ],
      ),
    );
  }

  /// 사용 방법 항목 위젯
  Widget _buildInstruction({required String number, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: AppSizes.fontSizeXS,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 주의사항 항목 위젯
  Widget _buildCautionItem({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.orange, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(height: 1.4),
          ),
        ),
      ],
    );
  }

  /// 팁 항목 위젯
  Widget _buildTipItem(
      {required IconData icon,
      required String text,
      bool isHighlighted = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.purple, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              height: 1.4,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              fontSize:
                  isHighlighted ? AppSizes.fontSizeMD : AppSizes.fontSizeSM,
            ),
          ),
        ),
      ],
    );
  }
}
