import 'package:flutter/material.dart';

enum NavigationTab {
  home, // 새로 추가할 홈 탭
  dashboard, // 이름을 '과제'로 변경할 현재 홈 탭
  progress,
  reflection,
}

class BottomNavBar extends StatelessWidget {
  final NavigationTab currentTab;
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
                icon: Icons.home, // 홈 아이콘 유지
                label: '홈', // 새 홈 탭
                tab: NavigationTab.home,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.assignment, // 과제에 더 적합한 아이콘으로 변경
                label: '과제', // 기존 홈을 과제로 변경
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
