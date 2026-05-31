import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/state/app_state.dart';
import 'features/auth/auth_gate.dart';
import 'widgets/firebase_status_overlay.dart';

class SupportWorkerLogApp extends StatefulWidget {
  const SupportWorkerLogApp({super.key});

  @override
  State<SupportWorkerLogApp> createState() => _SupportWorkerLogAppState();
}

class _SupportWorkerLogAppState extends State<SupportWorkerLogApp> {
  late final AppState _appState;

  static const bg = Color(0xFF090E17);
  static const panel = Color(0xFF151B29);
  static const panel2 = Color(0xFF20283B);
  static const border = Color(0xFF34405F);
  static const blue = Color(0xFF4F8DF7);
  static const green = Color(0xFF31E981);
  static const muted = Color(0xFF8396C7);

  @override
  void initState() {
    super.initState();
    _appState = AppState();
    unawaited(_appState.load().catchError((_) {}));
  }

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: blue,
          brightness: Brightness.dark,
        ).copyWith(
          surface: panel,
          primary: blue,
          secondary: green,
          outline: border,
        );

    return ChangeNotifierProvider.value(
      value: _appState,
      child: MaterialApp(
        title: 'Support Worker Log',
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return FirebaseStatusOverlay(child: child ?? const SizedBox.shrink());
        },
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: scheme,
          scaffoldBackgroundColor: bg,
          canvasColor: bg,
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          appBarTheme: const AppBarTheme(
            backgroundColor: bg,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            height: 68,
            backgroundColor: panel,
            indicatorColor: const Color(0xFF13294D),
            surfaceTintColor: Colors.transparent,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: blue, size: 23);
              }

              return const IconThemeData(color: muted, size: 22);
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                );
              }

              return const TextStyle(
                color: muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              );
            }),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: panel2,
            labelStyle: const TextStyle(color: muted),
            hintStyle: const TextStyle(color: muted),
            helperStyle: const TextStyle(color: muted),
            prefixIconColor: muted,
            suffixIconColor: muted,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: blue, width: 2),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: border, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: blue,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          cardTheme: CardThemeData(
            color: panel,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: border),
            ),
          ),
          chipTheme: ChipThemeData(
            backgroundColor: panel2,
            selectedColor: const Color(0xFF13294D),
            labelStyle: const TextStyle(
              color: Color(0xFFD8E2FF),
              fontWeight: FontWeight.w700,
            ),
            secondaryLabelStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
            side: const BorderSide(color: border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          dropdownMenuTheme: DropdownMenuThemeData(
            textStyle: const TextStyle(color: Colors.white),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: panel2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          listTileTheme: const ListTileThemeData(
            iconColor: muted,
            textColor: Colors.white,
            tileColor: Colors.transparent,
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: panel,
            surfaceTintColor: Colors.transparent,
            modalBackgroundColor: panel,
            modalBarrierColor: Color(0x99000000),
            dragHandleColor: muted,
          ),
          snackBarTheme: SnackBarThemeData(
            backgroundColor: panel2,
            contentTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          dividerTheme: const DividerThemeData(color: border),
          textTheme: ThemeData.dark().textTheme.apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
        ),
        home: const AuthGate(),
      ),
    );
  }
}
