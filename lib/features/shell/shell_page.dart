import 'package:flutter/material.dart';

class ShellPage {
  const ShellPage({
    required this.title,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.screen,
  });

  final String title;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;
}
