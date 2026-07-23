import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<void> initialization;

  @override
  void initState() {
    super.initState();
    initialization = _initialize();
  }

  Future<void> _initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    }
  }

  void _retry() {
    setState(() => initialization = _initialize());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return const SupportWorkerLogApp();
        }

        return MaterialApp(
          title: 'Support Worker Log',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF090E17),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF4F8DF7),
              brightness: Brightness.dark,
            ),
          ),
          home: _StartupScreen(
            error: snapshot.hasError ? snapshot.error : null,
            onRetry: _retry,
          ),
        );
      },
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF151B29),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFF34405F)),
                    ),
                    child: const Icon(
                      Icons.work_history_outlined,
                      color: Color(0xFF4F8DF7),
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Support Worker Log',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (error == null) ...[
                    const SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Opening your saved work...',
                      style: TextStyle(color: Color(0xFF8396C7)),
                    ),
                  ] else ...[
                    const Text(
                      'The app could not finish starting. Your saved data has '
                      'not been changed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFFFC857), height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
