// lib/widgets/ui/custom_button.dart
import 'package:flutter/material.dart';

/// 커스텀 버튼 위젯
///
/// 앱 전체에서 일관된 스타일의 버튼을 사용할 수 있도록 도와줍니다.
/// 일반 버튼과 아웃라인 버튼 스타일을 지원합니다.
class CustomButton extends StatelessWidget {
  /// 버튼 텍스트
  final String label;

  /// 버튼 클릭 시 실행할 콜백
  final VoidCallback onPressed;

  /// 버튼 배경색
  final Color backgroundColor;

  /// 버튼 텍스트 색상
  final Color textColor;

  /// 버튼 너비
  final double width;

  /// 버튼 높이
  final double height;

  /// 버튼 모서리 둥글기
  final double borderRadius;

  /// 아웃라인 버튼 여부
  final bool isOutlined;

  /// 아이콘 (선택 사항)
  final IconData? icon;

  /// 버튼 비활성화 여부
  final bool isDisabled;

  /// 로딩 상태 표시 여부
  final bool isLoading;

  const CustomButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.backgroundColor = Colors.blue,
    this.textColor = Colors.white,
    this.width = 120,
    this.height = 40,
    this.borderRadius = 8,
    this.isOutlined = false,
    this.icon,
    this.isDisabled = false,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: isOutlined ? _buildOutlinedButton() : _buildElevatedButton(),
    );
  }

  /// 아웃라인 버튼 생성
  Widget _buildOutlinedButton() {
    return OutlinedButton(
      onPressed: isDisabled || isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: backgroundColor,
        side: BorderSide(
            color: isDisabled ? Colors.grey.shade300 : backgroundColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      child: _buildButtonContent(),
    );
  }

  /// 일반 버튼 생성
  Widget _buildElevatedButton() {
    return ElevatedButton(
      onPressed: isDisabled || isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        disabledBackgroundColor: Colors.grey.shade300,
        disabledForegroundColor: Colors.grey.shade500,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      child: _buildButtonContent(),
    );
  }

  /// 버튼 내부 콘텐츠 생성
  Widget _buildButtonContent() {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            isOutlined ? backgroundColor : textColor,
          ),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    return Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }
}

/// 커스텀 아이콘 버튼 위젯
class CustomIconButton extends StatelessWidget {
  /// 버튼 아이콘
  final IconData icon;

  /// 버튼 클릭 시 실행할 콜백
  final VoidCallback onPressed;

  /// 버튼 배경색
  final Color backgroundColor;

  /// 버튼 아이콘 색상
  final Color iconColor;

  /// 버튼 크기
  final double size;

  /// 아이콘 크기
  final double iconSize;

  /// 버튼 모서리 둥글기
  final double borderRadius;

  /// 버튼 비활성화 여부
  final bool isDisabled;

  /// 툴팁 텍스트
  final String? tooltip;

  const CustomIconButton({
    Key? key,
    required this.icon,
    required this.onPressed,
    this.backgroundColor = Colors.blue,
    this.iconColor = Colors.white,
    this.size = 40,
    this.iconSize = 20,
    this.borderRadius = 8,
    this.isDisabled = false,
    this.tooltip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Widget buttonWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDisabled ? Colors.grey.shade300 : backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: isDisabled ? null : onPressed,
          child: Icon(
            icon,
            color: isDisabled ? Colors.grey.shade500 : iconColor,
            size: iconSize,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: buttonWidget,
      );
    }

    return buttonWidget;
  }
}

/// 텍스트 버튼 위젯
class CustomTextButton extends StatelessWidget {
  /// 버튼 텍스트
  final String label;

  /// 버튼 클릭 시 실행할 콜백
  final VoidCallback onPressed;

  /// 버튼 텍스트 색상
  final Color textColor;

  /// 버튼 비활성화 여부
  final bool isDisabled;

  /// 아이콘 (선택 사항)
  final IconData? icon;

  /// 패딩
  final EdgeInsetsGeometry padding;

  const CustomTextButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.textColor = Colors.blue,
    this.isDisabled = false,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: isDisabled ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: textColor,
        padding: padding,
      ),
      child: icon != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16),
                const SizedBox(width: 4),
                Text(label),
              ],
            )
          : Text(label),
    );
  }
}
