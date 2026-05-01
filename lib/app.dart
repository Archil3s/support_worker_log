import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/state/app_state.dart';
import 'features/shell/main_shell.dart';

class SupportWorkerLogApp extends StatefulWidget {
  const SupportWorkerLogApp({super.key});

  @override
  State<SupportWorkerLogApp> createState() => _SupportWorkerLogAppState();
}

class _SupportWorkerLogAppState extends State<SupportWorkerLogApp> {
  late final AppState _appState;
  late Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _appState = AppState();
    _loadFuture = _appState.load();
  }

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _appState,
      child: MaterialApp(
        title: 'Support Worker Log',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          scaffoldBackgroundColor: const Color(0xFFF6F7F9),
        ),
        home: FutureBuilder<void>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _LoadingScreen();
            }

            if (snapshot.hasError) {
              return _LoadErrorScreen(
                onRetry: () {
                  setState(() {
                    _loadFuture = _appState.load();
                  });
                },
              );
            }

            return const MainShell();
          },
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _LoadErrorScreen extends StatelessWidget {
  const _LoadErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support Worker Log')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              const Text(
                'The app could not load saved data.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
