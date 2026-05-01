import 'package:flutter/material.dart';

import 'features/shell/main_shell.dart';

class SupportWorkerLogApp extends StatelessWidget {
  const SupportWorkerLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Support Worker Log',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        scaffoldBackgroundColor: const Color(0xFFF6F7F9),
      ),
      home: const MainShell(),
    );
  }
}
