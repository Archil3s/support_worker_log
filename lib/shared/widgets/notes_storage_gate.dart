import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/google_export_account_scope.dart';
import '../../core/state/app_state.dart';
import 'google_account_connection_card.dart';
import 'section_card.dart';

class NotesStorageGate extends StatefulWidget {
  const NotesStorageGate({
    super.key,
    required this.child,
    this.scope,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 24),
    this.scrollable = true,
    this.title = 'Notes Locked',
    this.message =
        'Notes are hidden until Firebase sync and Google Drive are both connected.',
    this.disconnectedText =
        'Notes are locked until Firebase sync and Drive are connected.',
    this.connectedServiceText,
  });

  final Widget child;
  final GoogleExportAccountScope? scope;
  final EdgeInsets padding;
  final bool scrollable;
  final String title;
  final String message;
  final String disconnectedText;
  final String? connectedServiceText;

  @override
  State<NotesStorageGate> createState() => _NotesStorageGateState();
}

class _NotesStorageGateState extends State<NotesStorageGate> {
  bool syncing = false;
  String? message;

  Future<void> _syncNow() async {
    if (syncing) return;

    setState(() {
      syncing = true;
      message = null;
    });

    try {
      await context.read<AppState>().syncNow();
    } catch (error) {
      if (!mounted) return;
      setState(() => message = error.toString());
    } finally {
      if (mounted) {
        setState(() => syncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final scope = widget.scope ?? appState.notesGoogleScope;

    if (appState.notesStorageReadyForScope(scope)) {
      return widget.child;
    }

    final reasons = <String>[
      if (!appState.isSignedIn) 'Sign in to Firebase.',
      if (appState.isSignedIn &&
          (!appState.cloudSyncReady || appState.cloudSyncError != null))
        'Wait for Firebase sync to be ready.',
      if (!appState.googleDriveConnectedForScope(scope))
        'Connect ${scope.label} Google Drive.',
    ];

    final children = [
      SectionCard(
        title: widget.title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_outline, size: 38, color: Color(0xFFFFC857)),
            const SizedBox(height: 10),
            Text(
              widget.message,
              style: TextStyle(color: Color(0xFFFFD98C), height: 1.35),
            ),
            if (reasons.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final reason in reasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: Color(0xFF8396C7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reason,
                          style: const TextStyle(
                            color: Color(0xFFB8C7F3),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (appState.isSignedIn &&
                (!appState.cloudSyncReady ||
                    appState.cloudSyncError != null)) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: syncing ? null : () => unawaited(_syncNow()),
                icon: syncing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_outlined),
                label: Text(syncing ? 'Syncing...' : 'Sync Now'),
              ),
            ],
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: const TextStyle(
                  color: Color(0xFFFF6B6B),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      GoogleAccountConnectionCard(
        scope: scope,
        disconnectedText: widget.disconnectedText,
        connectedServiceText: widget.connectedServiceText,
      ),
    ];

    if (!widget.scrollable) {
      return Padding(
        padding: widget.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
    }

    return ListView(padding: widget.padding, children: children);
  }
}
