import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final double elevation;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final Widget? header;
  final Color headerColor;
  final bool useGradient;
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
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }
}
