import 'package:flutter/material.dart';

class AppBootLogo extends StatelessWidget {
  const AppBootLogo({
    super.key,
    this.size = 72,
    this.borderRadius = 22,
    this.fontSize = 30,
    this.backgroundColor = const Color(0xFF151B29),
    this.foregroundColor = const Color(0xFF4F8DF7),
    this.borderColor = const Color(0xFF34405F),
  });

  final double size;
  final double borderRadius;
  final double fontSize;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('app-boot-logo'),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        'S',
        style: TextStyle(
          color: foregroundColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
