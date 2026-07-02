import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/google_export_account_scope.dart';
import '../../core/state/app_state.dart';
import 'google_account_connection_card.dart';

class NotesStorageGate extends StatefulWidget {
  const NotesStorageGate({
    super.key,
    required this.child,
    this.scope,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 24),
    this.scrollable = true,
    this.title = 'Access Required',
    this.message =
        'This tab unlocks when app sync and Google Drive are connected.',
    this.disconnectedText =
        'Google Drive permission is needed to save or sync notes.',
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

    final card = GoogleAccountConnectionCard(
      scope: scope,
      title: widget.title,
      accessMessage: widget.message,
      disconnectedText: widget.disconnectedText,
      connectedServiceText: widget.connectedServiceText,
      showAccessChecklist: true,
      syncingAppState: syncing,
      syncMessage: message,
      onSyncNow: () => unawaited(_syncNow()),
    );

    if (!widget.scrollable) {
      return Padding(padding: widget.padding, child: card);
    }

    return ListView(padding: widget.padding, children: [card]);
  }
}
