// lib/widgets/bottom_nav_bar.dart
import 'package:flutter/material.dart';

/// 네비게이션 탭 enum
enum NavigationTab {
  dashboard, // 홈 대시보드
  progress, // 진도 화면
  reflection, // 성찰 화면
}

/// 바텀 네비게이션 바 위젯
///
/// 앱의 주요 화면 간 이동을 위한 하단 네비게이션을 제공합니다.
class BottomNavBar extends StatelessWidget {
  /// 현재 선택된 탭
  final NavigationTab currentTab;

  /// 탭 선택 콜백
  final Function(NavigationTab) onTabSelected;

  const BottomNavBar({
    Key? key,
    required this.currentTab,
    required this.onTabSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context: context,
                icon: Icons.home,
                label: '홈',
                tab: NavigationTab.dashboard,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.check_circle_outline,
                label: '진도',
                tab: NavigationTab.progress,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.book_outlined,
                label: '성찰',
                tab: NavigationTab.reflection,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 각 네비게이션 아이템을 구성하는 메서드
  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required NavigationTab tab,
  }) {
    final isSelected = currentTab == tab;
    final color = isSelected ? Theme.of(context).primaryColor : Colors.grey;

    return GestureDetector(
      onTap: () => onTabSelected(tab),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 탭별 화면 구성 위젯
///
/// 현재 선택된 탭에 따라 적절한 화면을 표시합니다.
class NavigationTabView extends StatelessWidget {
  /// 현재 선택된 탭
  final NavigationTab currentTab;

  /// 대시보드 화면 위젯
  final Widget dashboardScreen;

  /// 진도 화면 위젯
  final Widget progressScreen;

  /// 성찰 화면 위젯
  final Widget reflectionScreen;

  /// 탭 변경 콜백
  final Function(NavigationTab) onTabChanged;

  const NavigationTabView({
    Key? key,
    required this.currentTab,
    required this.dashboardScreen,
    required this.progressScreen,
    required this.reflectionScreen,
    required this.onTabChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: BottomNavBar(
        currentTab: currentTab,
        onTabSelected: onTabChanged,
      ),
    );
  }

  /// 현재 탭에 맞는 화면 위젯 반환
  Widget _buildBody() {
    switch (currentTab) {
      case NavigationTab.dashboard:
        return dashboardScreen;
      case NavigationTab.progress:
        return progressScreen;
      case NavigationTab.reflection:
        return reflectionScreen;
      default:
        return dashboardScreen;
    }
  }
}
