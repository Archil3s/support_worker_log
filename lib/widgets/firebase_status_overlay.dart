import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/state/app_state.dart';

class FirebaseStatusOverlay extends StatefulWidget {
  const FirebaseStatusOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<FirebaseStatusOverlay> createState() => _FirebaseStatusOverlayState();
}

class _FirebaseStatusOverlayState extends State<FirebaseStatusOverlay> {
  Timer? _autoSyncTimer;

  bool _expanded = false;
  bool _syncing = false;
  String? _lastAutoSyncUid;
  String? _manualMessage;
  DateTime? _lastChecked;

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  void _scheduleFirstLoginSync(String uid) {
    if (_lastAutoSyncUid == uid) return;

    _lastAutoSyncUid = uid;
    _autoSyncTimer?.cancel();

    _autoSyncTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _syncNow();
    });
  }

  Future<void> _syncNow() async {
    if (!mounted || _syncing) return;

    final appState = context.read<AppState>();

    if (!appState.isSignedIn) {
      setState(() {
        _manualMessage = 'No signed-in user. Sign in first.';
        _lastChecked = DateTime.now();
      });
      return;
    }

    setState(() {
      _syncing = true;
      _manualMessage = 'Syncing to Firebase...';
    });

    try {
      await appState.syncNow().timeout(const Duration(seconds: 25));

      if (!mounted) return;

      final updatedState = context.read<AppState>();

      setState(() {
        _lastChecked = DateTime.now();

        if (updatedState.cloudSyncError == null &&
            updatedState.cloudSyncReady) {
          _manualMessage = 'Live and synced to Firebase Firestore';
        } else if (updatedState.cloudSyncError != null) {
          _manualMessage = 'Sync warning: ${updatedState.cloudSyncError}';
        } else {
          _manualMessage = 'Signed in, but Firebase sync is not ready yet.';
        }
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _manualMessage = 'Sync failed: $error';
        _lastChecked = DateTime.now();
      });
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    if (!mounted || _syncing) return;

    setState(() {
      _syncing = true;
      _manualMessage = 'Logging out...';
    });

    try {
      await context.read<AppState>().signOut();

      if (!mounted) return;

      setState(() {
        _expanded = false;
        _syncing = false;
        _manualMessage = null;
        _lastAutoSyncUid = null;
        _lastChecked = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _syncing = false;
        _manualMessage = 'Logout failed: $error';
        _lastChecked = DateTime.now();
      });
    }
  }

  String _userLabel(User user) {
    return user.email ?? user.displayName ?? user.phoneNumber ?? user.uid;
  }

  bool _isLive(AppState appState) {
    return appState.isSignedIn &&
        appState.cloudSyncReady &&
        appState.cloudSyncError == null;
  }

  String _firebaseLabel(AppState appState) {
    if (_syncing) return 'Syncing...';
    if (_isLive(appState)) return 'Firebase live';
    if (appState.cloudSyncError != null) return 'Firebase warning';
    return 'Firebase pending';
  }

  String _statusMessage(AppState appState) {
    if (_syncing) return _manualMessage ?? 'Syncing to Firebase...';
    if (_manualMessage != null) return _manualMessage!;
    if (_isLive(appState)) return 'Live and synced to Firebase Firestore';
    if (appState.cloudSyncError != null) {
      return 'Sync warning: ${appState.cloudSyncError}';
    }
    return 'Signed in. Waiting for first Firebase sync...';
  }

  Widget _actionButton({required String label, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF4F8DF7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _collapsed({required User user, required AppState appState}) {
    final live = _isLive(appState);

    return GestureDetector(
      onTap: () {
        setState(() {
          _expanded = true;
        });
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF151B29),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF34405F)),
          boxShadow: const [
            BoxShadow(
              blurRadius: 18,
              offset: Offset(0, 8),
              color: Color(0x55000000),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              live ? Icons.cloud_done : Icons.cloud_sync,
              color: live ? const Color(0xFF31E981) : const Color(0xFFFFC857),
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${_userLabel(user)} | ${_firebaseLabel(appState)}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _expandedPanel({required User user, required AppState appState}) {
    final live = _isLive(appState);

    final statusColor = live
        ? const Color(0xFF31E981)
        : appState.cloudSyncError != null
        ? const Color(0xFFFF6B6B)
        : const Color(0xFFFFC857);

    final statusIcon = live
        ? Icons.cloud_done
        : appState.cloudSyncError != null
        ? Icons.cloud_off
        : Icons.cloud_sync;

    return Container(
      width: 390,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF34405F)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 24,
            offset: Offset(0, 10),
            color: Color(0x66000000),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          decoration: TextDecoration.none,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'App Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _expanded = false;
                    });
                  },
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Currently logged in',
              style: TextStyle(
                color: Color(0xFF8396C7),
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _userLabel(user),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'UID: ${user.uid}',
              style: const TextStyle(
                color: Color(0xFF8396C7),
                fontSize: 12,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(statusIcon, color: statusColor, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _statusMessage(appState),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
            if (_lastChecked != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last checked: $_lastChecked',
                style: const TextStyle(
                  color: Color(0xFF8396C7),
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _actionButton(
                  label: _syncing ? 'Syncing...' : 'Sync Now',
                  onTap: _syncing ? null : _syncNow,
                ),
                _actionButton(
                  label: _syncing ? 'Please wait...' : 'Logout',
                  onTap: _syncing ? null : _logout,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            final user = snapshot.data ?? FirebaseAuth.instance.currentUser;

            if (user == null) {
              _lastAutoSyncUid = null;
              return widget.child;
            }

            _scheduleFirstLoginSync(user.uid);

            return Stack(
              fit: StackFit.expand,
              children: [
                widget.child,
                Positioned(
                  top: 36,
                  right: 12,
                  child: _expanded
                      ? _expandedPanel(user: user, appState: appState)
                      : _collapsed(user: user, appState: appState),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
