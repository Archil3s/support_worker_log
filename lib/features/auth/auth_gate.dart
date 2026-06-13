import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/app_lock_service.dart';
import '../../core/state/app_state.dart';
import '../shell/main_shell.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (appState.isSignedIn) {
      if (!appState.appUnlocked) return const AppLockScreen();

      return const MainShell();
    }

    return const AuthScreen();
  }
}

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final service = AppLockService();
  final lockPasswordController = TextEditingController();

  bool busy = false;
  String? errorText;
  DateTime? lockedUntil;
  Timer? lockoutTimer;

  bool get lockedOut {
    final until = lockedUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  @override
  void initState() {
    super.initState();
    _loadLockout();
  }

  @override
  void dispose() {
    lockoutTimer?.cancel();
    lockPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadLockout() async {
    final until = await service.lockedUntil();
    if (!mounted) return;

    setState(() => lockedUntil = until);
    _startLockoutTimer();
  }

  Future<void> _submit() async {
    final activeLockout = await service.lockedUntil();
    if (activeLockout != null) {
      setState(() {
        lockedUntil = activeLockout;
        errorText = null;
      });
      _startLockoutTimer();
      return;
    }

    final password = lockPasswordController.text.trim();
    if (password.isEmpty) {
      setState(() => errorText = 'Enter the app password.');
      return;
    }

    setState(() {
      busy = true;
      errorText = null;
    });

    if (!service.verifyPassword(password)) {
      final until = await service.recordFailedAttempt();
      if (!mounted) return;

      setState(() {
        busy = false;
        lockedUntil = until;
        errorText = until == null
            ? 'Wrong password.'
            : 'Too many wrong passwords. Try again in ${_lockoutRemaining()}.';
      });
      _startLockoutTimer();
      return;
    }

    await service.clearLockout();
    if (!mounted) return;

    await context.read<AppState>().unlockApp();
  }

  Future<void> _signOut() async {
    setState(() {
      busy = true;
      errorText = null;
    });

    try {
      await context.read<AppState>().signOut();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        busy = false;
        errorText = error.toString();
      });
    }
  }

  void _startLockoutTimer() {
    lockoutTimer?.cancel();
    if (!lockedOut) return;

    lockoutTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;

      if (!lockedOut) {
        lockoutTimer?.cancel();
        await service.clearLockout();
        if (!mounted) return;

        setState(() {
          lockedUntil = null;
          errorText = null;
        });
        return;
      }

      setState(() {});
    });
  }

  String _lockoutRemaining() {
    final until = lockedUntil;
    if (until == null) return '0:00';

    final remaining = until.difference(DateTime.now());
    final seconds = remaining.inSeconds < 0 ? 0 : remaining.inSeconds + 1;
    final minutesPart = seconds ~/ 60;
    final secondsPart = seconds % 60;
    return '$minutesPart:${secondsPart.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final lockoutMessage = lockedOut
        ? 'Too many wrong passwords. Try again in ${_lockoutRemaining()}.'
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Support Worker Log')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF151B29),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF34405F)),
              ),
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 44,
                      color: Color(0xFF4F8DF7),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Enter app password',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 18),
                    _AppPasswordField(
                      controller: lockPasswordController,
                      enabled: !busy && !lockedOut,
                      onSubmitted: (_) {
                        if (!busy && !lockedOut) _submit();
                      },
                    ),
                    if (lockoutMessage != null || errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        lockoutMessage ?? errorText!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFF6B6B),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: busy || lockedOut ? null : _submit,
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_open_outlined),
                      label: const Text('Unlock'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: busy ? null : _signOut,
                      child: const Text('Use different sign-in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppPasswordField extends StatelessWidget {
  const _AppPasswordField({
    required this.controller,
    required this.enabled,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.password_outlined),
      ),
      onSubmitted: onSubmitted,
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool createAccount = false;
  bool busy = false;
  String? errorText;
  String? successText;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    setState(() {
      busy = true;
      errorText = null;
      successText = null;
    });

    try {
      final appState = context.read<AppState>();

      if (createAccount) {
        await appState.register(email: email, password: password);
      } else {
        await appState.signIn(email: email, password: password);
      }
    } catch (error) {
      setState(() => errorText = _friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      busy = true;
      errorText = null;
      successText = null;
    });

    try {
      await context.read<AppState>().signInWithGoogle();
    } catch (error) {
      setState(() => errorText = _friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      setState(() => errorText = 'Enter your email first.');
      return;
    }

    setState(() {
      busy = true;
      errorText = null;
      successText = null;
    });

    try {
      await context.read<AppState>().sendPasswordResetEmail(email);
      setState(() => successText = 'Password reset email sent.');
    } catch (error) {
      setState(() => errorText = _friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();

    if (text.contains('invalid-email')) return 'Enter a valid email address.';
    if (text.contains('user-not-found')) {
      return 'No account found for this email.';
    }
    if (text.contains('wrong-password')) return 'Incorrect password.';
    if (text.contains('email-already-in-use')) {
      return 'An account already exists for this email.';
    }
    if (text.contains('weak-password')) {
      return 'Use a stronger password, at least 6 characters.';
    }
    if (text.contains('network-request-failed')) {
      return 'Network error. Check your connection.';
    }
    if (text.contains('popup-closed-by-user')) {
      return 'Google sign-in was cancelled.';
    }
    if (text.contains('unauthorized-domain')) {
      return 'This desktop app address is not authorized for Google sign-in.';
    }
    if (text.contains('account-exists-with-different-credential')) {
      return 'An account already exists with a different sign-in method.';
    }

    return text.replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Support Worker Log')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: ListView(
            padding: const EdgeInsets.all(16),
            shrinkWrap: true,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF151B29),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF34405F)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      createAccount
                          ? Icons.person_add_alt_1_outlined
                          : Icons.lock_outline,
                      size: 44,
                      color: const Color(0xFF4F8DF7),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      createAccount ? 'Create account' : 'Sign in',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your existing local data will be merged and saved to Firebase after login. Google sign-in also connects Calendar and Drive.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF8396C7), height: 1.35),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: emailController,
                      enabled: !busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      enabled: !busy,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.password_outlined),
                      ),
                      onSubmitted: (_) {
                        if (!busy) _submit();
                      },
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFF6B6B),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    if (successText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        successText!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF31E981),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    if (appState.cloudSyncError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Sync warning: ${appState.cloudSyncError}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFFFC857)),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: busy ? null : _submit,
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              createAccount
                                  ? Icons.person_add_alt_1
                                  : Icons.login,
                            ),
                      label: Text(
                        createAccount
                            ? 'Create Account & Sync'
                            : 'Sign In & Sync',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : _signInWithGoogle,
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                      label: const Text('Continue with Google Sync'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              setState(() {
                                createAccount = !createAccount;
                                errorText = null;
                                successText = null;
                              });
                            },
                      child: Text(
                        createAccount
                            ? 'Already have an account? Sign in'
                            : 'Need an account? Create one',
                      ),
                    ),
                    TextButton(
                      onPressed: busy ? null : _resetPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
