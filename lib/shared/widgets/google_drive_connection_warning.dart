import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/google_export_account_scope.dart';
import '../../core/state/app_state.dart';
import 'google_account_selector.dart';
import 'google_session_countdown.dart';

class GoogleDriveConnectionWarning extends StatefulWidget {
  const GoogleDriveConnectionWarning({
    super.key,
    required this.scope,
    this.compact = false,
  });

  final GoogleExportAccountScope scope;
  final bool compact;

  @override
  State<GoogleDriveConnectionWarning> createState() =>
      _GoogleDriveConnectionWarningState();
}

class _GoogleDriveConnectionWarningState
    extends State<GoogleDriveConnectionWarning> {
  bool connecting = false;
  late bool expanded = !widget.compact;
  String? message;

  Future<void> _connect() async {
    setState(() {
      connecting = true;
      message = null;
    });

    try {
      await context.read<AppState>().connectGoogleDrive(scope: widget.scope);

      if (!mounted) return;

      setState(() {
        message = '${widget.scope.label} Google Drive connected.';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        message = _friendlyError(error);
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
    final connected = appState.googleDriveConnectedForScope(widget.scope);

    if (connected) return const SizedBox.shrink();

    final signedIn = appState.googleAccountSignedInForScope(widget.scope);
    final email = appState.googleAccountEmailForScope(widget.scope);
    final title = signedIn
        ? 'Google Drive needs reconnecting'
        : 'Google Drive is not connected';
    final detail = signedIn
        ? '${email ?? widget.scope.label} is known, but Drive permission is not active. '
              'Notes still save on this phone/web app first.'
        : 'Notes still save on this phone/web app first. Connect Drive before expecting files to upload.';

    if (widget.compact && !expanded) {
      return InkWell(
        onTap: () => setState(() => expanded = true),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF3A2812),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFC857), width: 1.2),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.add_to_drive_outlined,
                color: Color(0xFFFFC857),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  signedIn
                      ? 'Drive reconnect needed'
                      : 'Drive optional - tap to connect',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFE7A3),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFFFFC857),
                size: 20,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: widget.compact
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: EdgeInsets.all(widget.compact ? 12 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFF3A2812),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFC857), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFC857)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFFFE7A3),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: Color(0xFFFFD98C),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.compact) ...[
                const SizedBox(width: 6),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Collapse Google Drive controls',
                  onPressed: () => setState(() => expanded = false),
                  icon: const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Color(0xFFFFC857),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          GoogleAccountSelector(scope: widget.scope, compact: widget.compact),
          const SizedBox(height: 10),
          GoogleSessionCountdown(compact: widget.compact),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: connecting ? null : _connect,
            icon: connecting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_to_drive_outlined),
            label: Text(
              connecting
                  ? 'Connecting ${widget.scope.label} Drive'
                  : 'Connect ${widget.scope.label} Google Drive',
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              style: TextStyle(
                color:
                    message!.startsWith('Could') ||
                        message!.contains('cancelled') ||
                        message!.contains('timed out')
                    ? const Color(0xFFFF8A8A)
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
      return text.replaceFirst('Bad state: ', '').trim();
    }
    return text.isEmpty ? 'Could not connect Google Drive.' : text;
  }
}
