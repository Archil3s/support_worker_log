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
                    const SizedBox(height: 8),
                    const Text(
                      'Your app account and Google Drive stay signed in while '
                      'the app is locked.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF8396C7), height: 1.35),
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
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final emailFocusNode = FocusNode();
  final passwordFocusNode = FocusNode();
  final scrollController = ScrollController();

  bool createAccount = false;
  bool busy = false;
  bool showPassword = false;
  String? errorText;
  String? successText;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    emailFocusNode.dispose();
    passwordFocusNode.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (busy) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    final email = emailController.text.trim();
    final password = passwordController.text;
    FocusScope.of(context).unfocus();

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
      if (!mounted) return;
      setState(() => errorText = _friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (busy) return;
    FocusScope.of(context).unfocus();

    setState(() {
      busy = true;
      errorText = null;
      successText = null;
    });

    try {
      await context.read<AppState>().signInWithGoogle();
    } catch (error) {
      if (!mounted) return;
      setState(() => errorText = _friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    if (busy) return;

    final email = emailController.text.trim();

    if (_validateEmail(email) != null) {
      emailFocusNode.requestFocus();
      setState(() => errorText = 'Enter a valid email address first.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      busy = true;
      errorText = null;
      successText = null;
    });

    try {
      await context.read<AppState>().sendPasswordResetEmail(email);
      if (!mounted) return;
      setState(() => successText = 'Password reset email sent.');
    } catch (error) {
      if (!mounted) return;
      setState(() => errorText = _friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';

    final atIndex = email.indexOf('@');
    final dotIndex = email.lastIndexOf('.');
    if (atIndex <= 0 ||
        dotIndex <= atIndex + 1 ||
        dotIndex >= email.length - 1) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Enter your password.';
    if (createAccount && password.length < 6) {
      return 'Use at least 6 characters.';
    }

    return null;
  }

  String _friendlyError(Object error) {
    final text = error.toString();

    if (text.contains('invalid-email')) return 'Enter a valid email address.';
    if (text.contains('user-not-found')) {
      return 'No account found for this email.';
    }
    if (text.contains('wrong-password')) return 'Incorrect password.';
    if (text.contains('invalid-credential')) {
      return 'Email or password is incorrect.';
    }
    if (text.contains('email-already-in-use')) {
      return 'An account already exists for this email.';
    }
    if (text.contains('weak-password')) {
      return 'Use a stronger password, at least 6 characters.';
    }
    if (text.contains('network-request-failed')) {
      return 'Could not connect. Check your internet and try again.';
    }
    if (text.contains('too-many-requests')) {
      return 'Too many attempts. Wait a moment, then try again.';
    }
    if (text.contains('user-disabled')) return 'This account is disabled.';
    if (text.contains('operation-not-allowed')) {
      return 'This sign-in method is temporarily unavailable.';
    }
    if (text.contains('popup-closed-by-user')) {
      return 'Google sign-in was cancelled.';
    }
    if (text.contains('popup-blocked')) {
      return 'Your browser blocked the Google sign-in window. Allow popups and try again.';
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

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Support Worker Log')),
      body: SafeArea(
        child: Scrollbar(
          controller: scrollController,
          interactive: true,
          child: SingleChildScrollView(
            controller: scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151B29),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF34405F)),
                  ),
                  child: AutofillGroup(
                    child: Form(
                      key: formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
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
                            createAccount
                                ? 'Create your app account'
                                : 'Sign in to your app',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            createAccount
                                ? 'Your existing visits stay on this device and are '
                                      'added to your new cloud account after sign-in.'
                                : 'Visits save on this device first. Signing in backs '
                                      'up and syncs your app data.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF8396C7),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const _LoginAccountGuide(),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: emailController,
                            focusNode: emailFocusNode,
                            enabled: !busy,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            autofillHints: const [AutofillHints.email],
                            validator: _validateEmail,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'you@example.com',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            onFieldSubmitted: (_) =>
                                passwordFocusNode.requestFocus(),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: passwordController,
                            focusNode: passwordFocusNode,
                            enabled: !busy,
                            obscureText: !showPassword,
                            enableSuggestions: false,
                            autocorrect: false,
                            textInputAction: TextInputAction.done,
                            autofillHints: [
                              createAccount
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            validator: _validatePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.password_outlined),
                              suffixIcon: IconButton(
                                tooltip: showPassword
                                    ? 'Hide password'
                                    : 'Show password',
                                onPressed: busy
                                    ? null
                                    : () {
                                        setState(
                                          () => showPassword = !showPassword,
                                        );
                                      },
                                icon: Icon(
                                  showPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            onFieldSubmitted: (_) {
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    createAccount
                                        ? Icons.person_add_alt_1
                                        : Icons.login,
                                  ),
                            label: Text(
                              createAccount
                                  ? 'Create account'
                                  : 'Sign in with email',
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: busy ? null : _signInWithGoogle,
                            icon: const Icon(
                              Icons.g_mobiledata_rounded,
                              size: 28,
                            ),
                            label: const Text('Sign in with Google'),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF101827),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Color(0xFF8EA7FF),
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Google sign-in also connects Drive. Email sign-in can connect Drive later.',
                                    style: TextStyle(
                                      color: Color(0xFF8396C7),
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () {
                                    setState(() {
                                      createAccount = !createAccount;
                                      showPassword = false;
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
                          if (!createAccount)
                            TextButton(
                              onPressed: busy ? null : _resetPassword,
                              child: const Text('Forgot password?'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginAccountGuide extends StatelessWidget {
  const _LoginAccountGuide();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27324B)),
      ),
      child: const Column(
        children: [
          _LoginAccountRow(
            icon: Icons.cloud_outlined,
            title: 'App account',
            subtitle: 'Backs up visits, settings, and app data',
          ),
          SizedBox(height: 10),
          Divider(height: 1),
          SizedBox(height: 10),
          _LoginAccountRow(
            icon: Icons.add_to_drive_outlined,
            title: 'Google Drive',
            subtitle: 'Stores notes and documents when connected',
          ),
        ],
      ),
    );
  }
}

class _LoginAccountRow extends StatelessWidget {
  const _LoginAccountRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF13294D),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF4F8DF7), size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF8396C7),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
