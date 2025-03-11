import 'package:flutter/material.dart';

class CustomTabBar extends StatefulWidget {
  final List<String> tabs;
  final Function(int) onTabChanged;
  final int initialIndex;
  final double height;
  final Color backgroundColor;
  final Color selectedTabColor;
  final Color unselectedTabColor;
  final Color selectedLabelColor;
  final Color unselectedLabelColor;
  final double borderRadius;

  const CustomTabBar({
    Key? key,
    required this.tabs,
    required this.onTabChanged,
    this.initialIndex = 0,
    this.height = 50,
    this.backgroundColor = const Color(0xFFE0E0E0),
    this.selectedTabColor = Colors.white,
    this.unselectedTabColor = Colors.transparent,
    this.selectedLabelColor = Colors.blue,
    this.unselectedLabelColor = Colors.grey,
    this.borderRadius = 16,
  }) : super(key: key);

  @override
  _CustomTabBarState createState() => _CustomTabBarState();
}

class _CustomTabBarState extends State<CustomTabBar> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(widget.tabs.length, (index) {
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedIndex = index;
                });
                widget.onTabChanged(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _selectedIndex == index 
                      ? widget.selectedTabColor 
                      : widget.unselectedTabColor,
                  borderRadius: BorderRadius.circular(widget.borderRadius - 4),
                  boxShadow: _selectedIndex == index
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    widget.tabs[index],
                    style: TextStyle(
                      color: _selectedIndex == index 
                          ? widget.selectedLabelColor 
                          : widget.unselectedLabelColor,
                      fontWeight: _selectedIndex == index 
                          ? FontWeight.bold 
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class CustomTabView extends StatefulWidget {
  final List<String> tabs;
  final List<Widget> tabViews;
  final int initialIndex;
  final double tabBarHeight;
  final Color backgroundColor;
  final Color selectedTabColor;
  final Color unselectedTabColor;
  final Color selectedLabelColor;
  final Color unselectedLabelColor;
  final double borderRadius;

  const CustomTabView({
    Key? key,
    required this.tabs,
    required this.tabViews,
    this.initialIndex = 0,
    this.tabBarHeight = 50,
    this.backgroundColor = const Color(0xFFE0E0E0),
    this.selectedTabColor = Colors.white,
    this.unselectedTabColor = Colors.transparent,
    this.selectedLabelColor = Colors.blue,
    this.unselectedLabelColor = Colors.grey,
    this.borderRadius = 16,
  }) : assert(tabs.length == tabViews.length, 'Tabs and views count must match'),
       super(key: key);

  @override
  _CustomTabViewState createState() => _CustomTabViewState();
}

class _CustomTabViewState extends State<CustomTabView> {
  late int _selectedIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 탭바
        CustomTabBar(
          tabs: widget.tabs,
          onTabChanged: _onTabChanged,
          initialIndex: _selectedIndex,
          height: widget.tabBarHeight,
          backgroundColor: widget.backgroundColor,
          selectedTabColor: widget.selectedTabColor,
          unselectedTabColor: widget.unselectedTabColor,
          selectedLabelColor: widget.selectedLabelColor,
          unselectedLabelColor: widget.unselectedLabelColor,
          borderRadius: widget.borderRadius,
        ),
        const SizedBox(height: 16),
        
        // 탭 내용
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            children: widget.tabViews,
          ),
        ),
      ],
    );
  }
}