import 'package:flutter/material.dart';

/// 다양한 스타일의 카드를 제공하는 커스텀 위젯
///
/// 일반 카드, 헤더가 있는 카드, 그라데이션 배경 카드 등을 지원합니다.
class CustomCard extends StatelessWidget {
  /// 카드 내부 콘텐츠
  final Widget child;

  /// 카드 배경색
  final Color backgroundColor;

  /// 카드 그림자 강도
  final double elevation;

  /// 카드 모서리 둥글기
  final BorderRadius? borderRadius;

  /// 카드 내부 패딩
  final EdgeInsetsGeometry padding;

  /// 카드 상단 헤더 (제공 시 표시)
  final Widget? header;

  /// 헤더 배경색
  final Color headerColor;

  /// 그라데이션 배경 사용 여부
  final bool useGradient;

  /// 그라데이션 색상 (useGradient가 true일 때 사용)
  final List<Color>? gradientColors;

  const CustomCard({
    Key? key,
    required this.child,
    this.backgroundColor = Colors.white,
    this.elevation = 2,
    this.borderRadius,
    this.padding = const EdgeInsets.all(16),
    this.header,
    this.headerColor = Colors.blue,
    this.useGradient = false,
    this.gradientColors,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final finalBorderRadius = borderRadius ?? BorderRadius.circular(16);

    return Card(
      elevation: elevation,
      shape: RoundedRectangleBorder(
        borderRadius: finalBorderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더가 있는 경우 표시
          if (header != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: useGradient ? null : headerColor,
                gradient: useGradient
                    ? LinearGradient(
                        colors:
                            gradientColors ?? [Colors.blue, Colors.blueAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                borderRadius: BorderRadius.only(
                  topLeft: finalBorderRadius.topLeft,
                  topRight: finalBorderRadius.topRight,
                ),
              ),
              child: header,
            ),
          // 본문 콘텐츠
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }
}
