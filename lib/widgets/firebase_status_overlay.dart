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
  Timer? _sessionCountdownTimer;

  bool _expanded = false;
  bool _syncing = false;
  bool _sessionExpiryRunning = false;
  String? _lastAutoSyncUid;
  String? _manualMessage;
  DateTime? _lastChecked;

  @override
  void initState() {
    super.initState();
    _sessionCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _lockIfSessionExpired();
    });
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _sessionCountdownTimer?.cancel();
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
      _manualMessage = 'Syncing app data...';
    });

    try {
      await appState.syncNow().timeout(const Duration(seconds: 25));

      if (!mounted) return;

      final updatedState = context.read<AppState>();

      setState(() {
        _lastChecked = DateTime.now();

        if (updatedState.cloudSyncError == null &&
            updatedState.cloudSyncReady) {
          _manualMessage = 'App data is backed up and up to date.';
        } else if (updatedState.cloudSyncError != null) {
          _manualMessage =
              'App sync needs attention: ${updatedState.cloudSyncError}';
        } else {
          _manualMessage = 'Signed in, but app sync is not ready yet.';
        }
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _manualMessage = 'App sync failed: $error';
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
      _manualMessage = 'Signing out...';
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
        _manualMessage = 'Sign out failed: $error';
        _lastChecked = DateTime.now();
      });
    }
  }

  Future<void> _lockIfSessionExpired() async {
    if (_sessionExpiryRunning || !mounted) return;

    final appState = context.read<AppState>();
    if (!appState.isSignedIn || appState.sessionExpiresAt == null) return;
    if (appState.sessionExpiresAt!.isAfter(DateTime.now())) return;

    _sessionExpiryRunning = true;

    try {
      await appState.lockAppIfSessionExpired();
    } finally {
      _sessionExpiryRunning = false;
    }
  }

  String _userLabel(User user) {
    return user.email ?? user.displayName ?? user.phoneNumber ?? user.uid;
  }

  String _syncLabel(AppState appState) {
    if (_syncing) return 'Syncing app data';

    return switch (appState.saveSyncStatus) {
      AppSaveSyncStatus.savingLocally => 'Saving locally…',
      AppSaveSyncStatus.savedLocally => 'Saved locally',
      AppSaveSyncStatus.syncing => 'Syncing…',
      AppSaveSyncStatus.synced => 'Synced',
      AppSaveSyncStatus.syncError => 'Saved locally',
    };
  }

  String _statusMessage(AppState appState) {
    if (_syncing) return _manualMessage ?? 'Syncing app data...';
    if (_manualMessage != null) return _manualMessage!;

    return switch (appState.saveSyncStatus) {
      AppSaveSyncStatus.savingLocally =>
        'Saving the latest change safely on this device.',
      AppSaveSyncStatus.savedLocally =>
        'Saved safely on this device. Notes remain available offline.',
      AppSaveSyncStatus.syncing =>
        'Saved locally. Sending the latest changes to app sync now.',
      AppSaveSyncStatus.synced =>
        'Saved locally and app data is backed up and up to date.',
      AppSaveSyncStatus.syncError =>
        'Saved safely on this device. App sync needs a retry: '
            '${appState.cloudSyncError}',
    };
  }

  String _timeText(BuildContext context, DateTime value) {
    final localValue = value.toLocal();
    final today = DateUtils.dateOnly(DateTime.now());
    final date = DateUtils.dateOnly(localValue);
    final time = TimeOfDay.fromDateTime(localValue).format(context);

    if (date == today) return time;

    return '${localValue.day}/${localValue.month}/${localValue.year} $time';
  }

  String _localSaveSubtitle(AppState appState) {
    final savedAt = appState.lastLocalSavedAt;
    if (savedAt == null) {
      return 'Notes are safe on this device, including offline.';
    }

    return 'Last saved locally at ${_timeText(context, savedAt)}. '
        'Notes are safe offline.';
  }

  String _cloudSyncSubtitle(AppState appState) {
    final message = _statusMessage(appState);
    final syncedAt = appState.lastCloudSyncedAt;
    if (syncedAt == null) return message;

    return '$message Last synced at ${_timeText(context, syncedAt)}.';
  }

  String? _sessionCountdownText(AppState appState) {
    final expiresAt = appState.sessionExpiresAt;
    if (expiresAt == null || !appState.isSignedIn) return null;

    final remaining = expiresAt.difference(DateTime.now());
    if (remaining <= Duration.zero) return 'App lock now';

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);

    if (hours > 0) {
      return 'App locks in ${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }

    return 'App locks in ${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  Widget _actionButton({
    required String label,
    required VoidCallback? onTap,
    Color color = const Color(0xFF4F8DF7),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
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

  Widget _collapsed({required AppState appState}) {
    final status = appState.saveSyncStatus;
    final live = status == AppSaveSyncStatus.synced;
    final saving = status == AppSaveSyncStatus.savingLocally;
    final syncing = _syncing || status == AppSaveSyncStatus.syncing;
    final sessionText = _sessionCountdownText(appState);
    final hasError = status == AppSaveSyncStatus.syncError;

    return GestureDetector(
      onTap: () {
        setState(() {
          _expanded = true;
        });
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 270),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
              saving
                  ? Icons.save_outlined
                  : live
                  ? Icons.cloud_done
                  : syncing
                  ? Icons.cloud_sync
                  : hasError
                  ? Icons.cloud_off_outlined
                  : Icons.save_outlined,
              color: saving
                  ? const Color(0xFFFFC857)
                  : live
                  ? const Color(0xFF31E981)
                  : syncing
                  ? const Color(0xFF67E8F9)
                  : hasError
                  ? const Color(0xFFFFC857)
                  : const Color(0xFF31E981),
              size: 17,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _syncLabel(appState),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  Text(
                    sessionText == null
                        ? 'Notes safe offline'
                        : 'Notes safe offline • $sessionText',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8396C7),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionCountdownRow(AppState appState) {
    final sessionText = _sessionCountdownText(appState);
    if (sessionText == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.timer_outlined, color: Color(0xFFFFC857), size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$sessionText\nThe app locks when this session ends. Your account stays signed in.',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _closeButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _expanded = false;
        });
      },
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF20283B),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF34405F)),
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _statusDetailRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF27324B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
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
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF9AAAD2),
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _expandedPanel({required User user, required AppState appState}) {
    final status = appState.saveSyncStatus;
    final live = status == AppSaveSyncStatus.synced;
    final driveConnected = appState.googleDriveConnectedForScope(
      appState.notesGoogleScope,
    );
    final driveEmail = appState.googleAccountEmailForScope(
      appState.notesGoogleScope,
    );
    final size = MediaQuery.sizeOf(context);
    final panelWidth = size.width < 430 ? size.width - 24 : 390.0;
    final panelMaxHeight = size.height < 720 ? size.height * 0.62 : 520.0;

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

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 390, maxHeight: panelMaxHeight),
      child: Container(
        width: panelWidth,
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Sync & Account',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    _closeButton(),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'App account',
                  style: TextStyle(
                    color: Color(0xFF8396C7),
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _userLabel(user),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 14),
                _statusDetailRow(
                  icon: status == AppSaveSyncStatus.savingLocally
                      ? Icons.save_as_outlined
                      : Icons.save_outlined,
                  color: status == AppSaveSyncStatus.savingLocally
                      ? const Color(0xFFFFC857)
                      : const Color(0xFF31E981),
                  title: status == AppSaveSyncStatus.savingLocally
                      ? 'Saving locally…'
                      : 'Saved locally',
                  subtitle: _localSaveSubtitle(appState),
                ),
                const SizedBox(height: 8),
                _statusDetailRow(
                  icon: statusIcon,
                  color: statusColor,
                  title: 'App cloud sync',
                  subtitle: _cloudSyncSubtitle(appState),
                ),
                const SizedBox(height: 8),
                _statusDetailRow(
                  icon: driveConnected
                      ? Icons.add_to_drive
                      : Icons.add_to_drive_outlined,
                  color: driveConnected
                      ? const Color(0xFF31E981)
                      : const Color(0xFFFFC857),
                  title: 'Google Drive',
                  subtitle: driveConnected
                      ? driveEmail ?? 'Connected for notes and documents.'
                      : 'Not connected. Local saving and app sync still work.',
                ),
                _sessionCountdownRow(appState),
                if (_lastChecked != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Last cloud check: ${TimeOfDay.fromDateTime(_lastChecked!).format(context)}',
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
                      label: _syncing ? 'Syncing...' : 'Sync app data',
                      onTap: _syncing ? null : _syncNow,
                    ),
                    _actionButton(
                      label: _syncing ? 'Please wait...' : 'Sign out',
                      onTap: _syncing ? null : _logout,
                      color: const Color(0xFF33405F),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        if (!appState.appUnlocked) return widget.child;

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
                if (_expanded)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        setState(() {
                          _expanded = false;
                        });
                      },
                      child: const SizedBox.expand(),
                    ),
                  ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 72),
                      child: Material(
                        color: Colors.transparent,
                        child: _expanded
                            ? GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {},
                                child: _expandedPanel(
                                  user: user,
                                  appState: appState,
                                ),
                              )
                            : _collapsed(appState: appState),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
