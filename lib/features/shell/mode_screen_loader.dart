import 'package:flutter/material.dart';

import '../../core/models/app_mode.dart';
import '../casework/casework_screen.dart' deferred as casework;
import '../cleaning/cleaning_screen.dart' deferred as cleaning;
import '../grocery/presentation/pages/grocery_screen.dart' deferred as grocery;
import '../massage/massage_screen.dart' deferred as massage;
import '../mood/presentation/pages/mood_tracker_screen.dart' deferred as mood;
import '../personal/personal_screen.dart' deferred as personal;

class ModeScreenLoader extends StatefulWidget {
  const ModeScreenLoader({required this.mode, super.key});

  final AppMode mode;

  @override
  State<ModeScreenLoader> createState() => _ModeScreenLoaderState();
}

class _ModeScreenLoaderState extends State<ModeScreenLoader> {
  late Future<Widget> _screen;

  @override
  void initState() {
    super.initState();
    _screen = _load(widget.mode);
  }

  @override
  void didUpdateWidget(covariant ModeScreenLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _screen = _load(widget.mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _screen,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _FeatureLoadError(onRetry: _retry);
        }
        return snapshot.data ?? const _FeatureLoadingView();
      },
    );
  }

  void _retry() {
    setState(() => _screen = _load(widget.mode));
  }
}

Future<Widget> _load(AppMode mode) async {
  return switch (mode) {
    AppMode.personal => _loadPersonal(),
    AppMode.massage => _loadMassage(),
    AppMode.mood => _loadMood(),
    AppMode.cleaning => _loadCleaning(),
    AppMode.grocery => _loadGrocery(),
    AppMode.casework => _loadCasework(),
    AppMode.work || AppMode.paye => throw StateError(
      '$mode does not use a standalone feature screen.',
    ),
  };
}

Future<Widget> _loadPersonal() async {
  await personal.loadLibrary();
  return personal.PersonalScreen();
}

Future<Widget> _loadMassage() async {
  await massage.loadLibrary();
  return massage.MassageScreen();
}

Future<Widget> _loadMood() async {
  await mood.loadLibrary();
  return mood.MoodTrackerScreen();
}

Future<Widget> _loadCleaning() async {
  await cleaning.loadLibrary();
  return cleaning.CleaningScreen();
}

Future<Widget> _loadGrocery() async {
  await grocery.loadLibrary();
  return grocery.GroceryScreen();
}

Future<Widget> _loadCasework() async {
  await casework.loadLibrary();
  return casework.CaseworkScreen();
}

class _FeatureLoadingView extends StatelessWidget {
  const _FeatureLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Opening feature...'),
        ],
      ),
    );
  }
}

class _FeatureLoadError extends StatelessWidget {
  const _FeatureLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Retry opening feature'),
      ),
    );
  }
}
