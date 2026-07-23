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
    final compact = MediaQuery.sizeOf(context).width < 430;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Scrollbar(
          controller: scrollController,
          interactive: true,
          child: SingleChildScrollView(
            controller: scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              compact ? 14 : 24,
              18,
              compact ? 14 : 24,
              24 + bottomInset,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _LoginBrand(),
                    SizedBox(height: compact ? 18 : 24),
                    Container(
                      padding: EdgeInsets.all(compact ? 18 : 22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF171F31), Color(0xFF121827)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF34405F)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x55000000),
                            blurRadius: 24,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: AutofillGroup(
                        child: Form(
                          key: formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _LoginHeading(createAccount: createAccount),
                              const SizedBox(height: 20),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF172033),
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: busy ? null : _signInWithGoogle,
                                icon: const Text(
                                  'G',
                                  style: TextStyle(
                                    color: Color(0xFF4285F4),
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                label: const Text(
                                  'Continue with Google',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const _LoginDivider(),
                              const SizedBox(height: 16),
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
                                  labelText: 'Email address',
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
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: showPassword
                                        ? 'Hide password'
                                        : 'Show password',
                                    onPressed: busy
                                        ? null
                                        : () {
                                            setState(
                                              () =>
                                                  showPassword = !showPassword,
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
                                _AuthMessageBanner(
                                  message: errorText!,
                                  color: const Color(0xFFFF6B6B),
                                  icon: Icons.error_outline,
                                ),
                              ],
                              if (successText != null) ...[
                                const SizedBox(height: 12),
                                _AuthMessageBanner(
                                  message: successText!,
                                  color: const Color(0xFF31E981),
                                  icon: Icons.check_circle_outline,
                                ),
                              ],
                              if (appState.cloudSyncError != null) ...[
                                const SizedBox(height: 12),
                                _AuthMessageBanner(
                                  message:
                                      'Sync warning: ${appState.cloudSyncError}',
                                  color: const Color(0xFFFFC857),
                                  icon: Icons.cloud_off_outlined,
                                ),
                              ],
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: busy ? null : _submit,
                                icon: busy
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        createAccount
                                            ? Icons.person_add_alt_1
                                            : Icons.arrow_forward,
                                      ),
                                label: Text(
                                  createAccount ? 'Create account' : 'Sign in',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                children: [
                                  if (!createAccount)
                                    TextButton(
                                      onPressed: busy ? null : _resetPassword,
                                      child: const Text('Forgot password?'),
                                    ),
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
                                          ? 'Back to sign in'
                                          : 'Create an account',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const _LoginSafetyNote(),
                            ],
                          ),
                        ),
                      ),
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

class _LoginBrand extends StatelessWidget {
  const _LoginBrand();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFF1B3158),
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          child: SizedBox.square(
            dimension: 42,
            child: Icon(
              Icons.favorite_outline,
              color: Color(0xFF67E8F9),
              size: 22,
            ),
          ),
        ),
        SizedBox(width: 11),
        Expanded(
          child: Text(
            'Support Worker Log',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginHeading extends StatelessWidget {
  const _LoginHeading({required this.createAccount});

  final bool createAccount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF18325F),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            createAccount
                ? Icons.person_add_alt_1_outlined
                : Icons.waving_hand_outlined,
            color: const Color(0xFF8EA7FF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                createAccount ? 'Create your account' : 'Welcome back',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                createAccount
                    ? 'Your current visits stay on this device and sync after signup.'
                    : 'Sign in to continue. Your notes remain saved on this device.',
                style: const TextStyle(color: Color(0xFF9AAAD2), height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoginDivider extends StatelessWidget {
  const _LoginDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFF34405F))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'or use email',
            style: TextStyle(
              color: Color(0xFF8396C7),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFF34405F))),
      ],
    );
  }
}

class _AuthMessageBanner extends StatelessWidget {
  const _AuthMessageBanner({
    required this.message,
    required this.color,
    required this.icon,
  });

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginSafetyNote extends StatelessWidget {
  const _LoginSafetyNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: Color(0xFF8396C7), size: 17),
        SizedBox(width: 7),
        Expanded(
          child: Text(
            'Google signs into the app and connects Drive. Email keeps Drive separate until you connect it.',
            style: TextStyle(
              color: Color(0xFF8396C7),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
