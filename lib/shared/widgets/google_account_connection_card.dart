import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/google_export_account_scope.dart';
import '../../core/state/app_state.dart';
import 'google_account_selector.dart';
import 'section_card.dart';

class GoogleAccountConnectionCard extends StatefulWidget {
  const GoogleAccountConnectionCard({super.key, required this.scope});

  final GoogleExportAccountScope scope;

  @override
  State<GoogleAccountConnectionCard> createState() =>
      _GoogleAccountConnectionCardState();
}

class _GoogleAccountConnectionCardState
    extends State<GoogleAccountConnectionCard> {
  bool connecting = false;
  String? message;
  bool messageIsError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmGoogleAccount();
    });
  }

  Future<void> _warmGoogleAccount() async {
    if (!mounted) return;

    try {
      await context.read<AppState>().warmGoogleExportAccount(widget.scope);
    } catch (_) {
      // Connect reports real sign-in errors when the button is tapped.
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
        forceRefresh: true,
      );

      if (!mounted) return;

      setState(() {
        message = '${widget.scope.label} Google account connected.';
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

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final connected = switch (widget.scope) {
      GoogleExportAccountScope.work => appState.workGoogleServicesConnected,
      GoogleExportAccountScope.personal =>
        appState.personalGoogleServicesConnected,
      GoogleExportAccountScope.paye => appState.payeGoogleServicesConnected,
    };
    final signedIn = switch (widget.scope) {
      GoogleExportAccountScope.work => appState.workGoogleAccountSignedIn,
      GoogleExportAccountScope.personal =>
        appState.personalGoogleAccountSignedIn,
      GoogleExportAccountScope.paye => appState.payeGoogleAccountSignedIn,
    };
    final email = switch (widget.scope) {
      GoogleExportAccountScope.work => appState.workGoogleAccountEmail,
      GoogleExportAccountScope.personal => appState.personalGoogleAccountEmail,
      GoogleExportAccountScope.paye => appState.payeGoogleAccountEmail,
    };
    final statusColor = connected
        ? const Color(0xFF31E981)
        : const Color(0xFFFFC857);
    final statusText = connected
        ? email ?? 'Connected'
        : signedIn
        ? '${email ?? 'Signed in'} - Drive permission missing'
        : 'Not connected';

    return SectionCard(
      title: '${widget.scope.label} Google Account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: statusColor),
            ),
            child: Row(
              children: [
                Icon(Icons.account_circle_outlined, color: statusColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statusText,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            connected
                ? _serviceText
                : 'Not ready for Drive uploads. In-app notes still save locally.',
            style: const TextStyle(color: Color(0xFF8396C7), height: 1.35),
          ),
          const SizedBox(height: 10),
          GoogleAccountSelector(scope: widget.scope),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: connecting ? null : _connect,
            icon: connecting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login_outlined),
            label: Text(
              connecting
                  ? 'Connecting ${widget.scope.label} Google'
                  : 'Choose ${widget.scope.label} Google Account',
            ),
          ),
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
        return 'Used for Google Calendar, Google Drive notes, invoices, and Docs files.';
      case GoogleExportAccountScope.personal:
        return 'Used for personal Google Drive notes and progress files.';
      case GoogleExportAccountScope.paye:
        return 'Used for PAYE job files and this separate work account.';
    }
  }
}
