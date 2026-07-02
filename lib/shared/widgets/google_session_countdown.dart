import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';

class GoogleSessionCountdown extends StatelessWidget {
  const GoogleSessionCountdown({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (tick) => tick),
      builder: (context, _) {
        final appState = context.watch<AppState>();
        final text = _countdownText(appState);
        if (text == null) return const SizedBox.shrink();

        return Row(
          children: [
            Icon(
              Icons.timer_outlined,
              size: compact ? 16 : 18,
              color: const Color(0xFFFFC857),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: const Color(0xFFFFD98C),
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String? _countdownText(AppState appState) {
    final expiresAt = appState.sessionExpiresAt;
    if (!appState.isSignedIn || expiresAt == null) return null;

    final remaining = expiresAt.difference(DateTime.now());
    if (remaining <= Duration.zero) return 'App auto-lock now';

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);

    if (hours > 0) {
      return 'App auto-locks in ${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }

    return 'App auto-locks in ${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }
}
