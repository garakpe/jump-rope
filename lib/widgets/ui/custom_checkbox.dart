import 'package:flutter/material.dart';

class CustomCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final Color activeColor;
  final Color checkColor;
  final double size;
  final BorderRadius? borderRadius;

  const CustomCheckbox({
    Key? key,
    required this.value,
    required this.onChanged,
    this.activeColor = Colors.blue,
    this.checkColor = Colors.white,
    this.size = 24.0,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onChanged(!value);
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: value ? activeColor : Colors.transparent,
          borderRadius: borderRadius ?? BorderRadius.circular(4),
          border: Border.all(
            color: value ? activeColor : Colors.grey.shade400,
            width: 2,
          ),
        ),
        child: value
            ? Icon(
                Icons.check,
                size: size * 0.8,
                color: checkColor,
              )
            : null,
      ),
    );
  }
}
