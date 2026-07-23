import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/google_export_account_scope.dart';
import '../../core/state/app_state.dart';
import 'google_account_selector.dart';
import 'google_drive_connection_animation.dart';
import 'google_session_countdown.dart';
import 'section_card.dart';

class GoogleAccountConnectionCard extends StatefulWidget {
  const GoogleAccountConnectionCard({
    super.key,
    required this.scope,
    this.title,
    this.accessMessage,
    this.disconnectedText =
        'Google Drive permission is needed to save or sync notes.',
    this.connectedServiceText,
    this.showAccessChecklist = false,
    this.syncingAppState = false,
    this.syncMessage,
    this.onSyncNow,
  });

  final GoogleExportAccountScope scope;
  final String? title;
  final String? accessMessage;
  final String disconnectedText;
  final String? connectedServiceText;
  final bool showAccessChecklist;
  final bool syncingAppState;
  final String? syncMessage;
  final VoidCallback? onSyncNow;

  @override
  State<GoogleAccountConnectionCard> createState() =>
      _GoogleAccountConnectionCardState();
}

class _GoogleAccountConnectionCardState
    extends State<GoogleAccountConnectionCard> {
  bool checkingSession = true;
  bool connecting = false;
  bool signingOut = false;
  String? message;
  bool messageIsError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmGoogleAccount();
    });
  }

  @override
  void didUpdateWidget(GoogleAccountConnectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _warmGoogleAccount();
      });
    }
  }

  Future<void> _warmGoogleAccount() async {
    if (!mounted) return;

    setState(() {
      checkingSession = true;
      message = null;
      messageIsError = false;
    });

    try {
      await context.read<AppState>().warmGoogleExportAccount(widget.scope);
    } catch (_) {
      // Connect reports real sign-in errors when the button is tapped.
    } finally {
      if (mounted) {
        setState(() => checkingSession = false);
      }
    }
  }

  Future<void> _connect() async {
    setState(() {
      connecting = true;
      message = null;
      messageIsError = false;
    });

    try {
      await context.read<AppState>().connectGoogleDrive(
        scope: widget.scope,
        forceRefresh: false,
      );

      if (!mounted) return;

      setState(() {
        message = '${widget.scope.label} Google Drive connected.';
        messageIsError = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        message = _friendlyError(error);
        messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => connecting = false);
      }
    }
  }

  Future<void> _signOut() async {
    setState(() {
      signingOut = true;
      message = null;
      messageIsError = false;
    });

    try {
      await context.read<AppState>().signOut();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        message = _friendlyError(error);
        messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => signingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final connected = appState.googleDriveConnectedForScope(widget.scope);
    final signedIn = appState.googleAccountSignedInForScope(widget.scope);
    final email = appState.googleAccountEmailForScope(widget.scope);
    final appSyncReady =
        appState.isSignedIn &&
        appState.cloudSyncReady &&
        appState.cloudSyncError == null;
    final cardTitle =
        widget.title ??
        (widget.showAccessChecklist
            ? 'Access Required'
            : '${widget.scope.label} Google Account');
    final statusColor = connected
        ? const Color(0xFF31E981)
        : const Color(0xFFFFC857);
    final statusText = connected
        ? 'Connected and ready'
        : checkingSession
        ? 'Checking saved Google login'
        : signedIn
        ? 'Drive permission needs reconnecting'
        : 'Google Drive not connected';
    final detailText = connected
        ? widget.connectedServiceText ?? _serviceText
        : signedIn
        ? 'Your app login is still active. Only Google Drive access needs reconnecting.'
        : widget.disconnectedText;

    if ((checkingSession && !connected) || connecting) {
      return GoogleDriveConnectionAnimation(reconnecting: connecting);
    }

    return SectionCard(
      title: cardTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showAccessChecklist) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  connected && appSyncReady
                      ? Icons.lock_open_outlined
                      : Icons.lock_outline,
                  color: const Color(0xFFFFC857),
                  size: 32,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.accessMessage ??
                        'This tab unlocks when app sync and Google Drive are connected.',
                    style: const TextStyle(
                      color: Color(0xFFFFD98C),
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _AccessCheckRow(
              label: 'App sync',
              value: appSyncReady
                  ? 'Connected'
                  : appState.isSignedIn
                  ? 'Needs sync'
                  : 'Sign in needed',
              ready: appSyncReady,
            ),
            const SizedBox(height: 8),
            _AccessCheckRow(
              label: 'Google Drive',
              value: connected
                  ? 'Connected'
                  : signedIn
                  ? 'Needs reconnecting'
                  : 'Permission needed',
              ready: connected,
            ),
            if (appState.isSignedIn && !appSyncReady) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: widget.syncingAppState ? null : widget.onSyncNow,
                icon: widget.syncingAppState
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_outlined),
                label: Text(widget.syncingAppState ? 'Syncing' : 'Sync Now'),
              ),
            ],
            if (widget.syncMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _friendlyError(widget.syncMessage!),
                style: const TextStyle(
                  color: Color(0xFFFF6B6B),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFF26385F)),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: connected
                    ? const [Color(0xFF13342B), Color(0xFF162A45)]
                    : const [Color(0xFF2D2819), Color(0xFF182540)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: statusColor.withValues(alpha: 0.55)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1728),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Icon(
                        connected
                            ? Icons.add_to_drive
                            : Icons.add_to_drive_outlined,
                        color: statusColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            connected
                                ? 'Google Drive is ready'
                                : 'Connect Google Drive',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            statusText,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      connected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: statusColor,
                    ),
                  ],
                ),
                if ((email ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x66101827),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_circle_outlined,
                          color: statusColor,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            email!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFEAF0FF),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  detailText,
                  style: const TextStyle(
                    color: Color(0xFFB8C4E2),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF101827),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF26385F)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Google account',
                  style: TextStyle(
                    color: Color(0xFF8396C7),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                GoogleAccountSelector(scope: widget.scope),
                const SizedBox(height: 10),
                const GoogleSessionCountdown(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: const Color(0xFF4F8DF7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: signingOut ? null : _connect,
            icon: const Icon(Icons.add_to_drive_outlined),
            label: Text(
              signedIn ? 'Reconnect Google Drive' : 'Connect a Google Account',
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 17, color: Color(0xFF8396C7)),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Your notes stay saved locally before anything syncs.',
                  style: TextStyle(
                    color: Color(0xFF8396C7),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          if (widget.showAccessChecklist) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: signingOut ? null : _signOut,
              icon: signingOut
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout_outlined),
              label: Text(signingOut ? 'Signing Out' : 'Sign out / reset'),
            ),
          ],
          if (message != null) ...[
            const SizedBox(height: 10),
            Text(
              message!,
              style: TextStyle(
                color: messageIsError
                    ? const Color(0xFFFF5C5C)
                    : const Color(0xFF31E981),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _friendlyError(Object error) {
    final text = error.toString().trim();

    if (text.startsWith('Bad state: ')) {
      return text.replaceFirst('Bad state: ', '');
    }

    return text;
  }

  String get _serviceText {
    switch (widget.scope) {
      case GoogleExportAccountScope.work:
        return 'Used for Google Drive notes, invoices, and Docs files.';
      case GoogleExportAccountScope.personal:
        return 'Used for personal Google Drive notes and progress files.';
      case GoogleExportAccountScope.paye:
        return 'Used for PAYE job files and this separate work account.';
    }
  }
}

class _AccessCheckRow extends StatelessWidget {
  const _AccessCheckRow({
    required this.label,
    required this.value,
    required this.ready,
  });

  final String label;
  final String value;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final color = ready ? const Color(0xFF31E981) : const Color(0xFFFFC857);

    return Row(
      children: [
        Icon(
          ready ? Icons.check_circle_outline : Icons.radio_button_unchecked,
          color: color,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFEAF0FF),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}
