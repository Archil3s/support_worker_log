import 'package:flutter/material.dart';

class GoogleDriveConnectionAnimation extends StatefulWidget {
  const GoogleDriveConnectionAnimation({super.key, required this.reconnecting});

  final bool reconnecting;

  @override
  State<GoogleDriveConnectionAnimation> createState() =>
      _GoogleDriveConnectionAnimationState();
}

class _GoogleDriveConnectionAnimationState
    extends State<GoogleDriveConnectionAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> pulse;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    pulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0.9), weight: 50),
    ]).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.reconnecting
        ? 'Reconnecting Google Drive'
        : 'Checking Google Drive';
    final detail = widget.reconnecting
        ? 'Finish the Google popup if it appears. Your notes are still saved locally.'
        : 'Looking for your saved Google account. No popup is needed.';

    return Semantics(
      container: true,
      liveRegion: true,
      label: title,
      child: Container(
        key: const Key('google-drive-connection-animation'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF16213A), Color(0xFF121827)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF345A9D)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 58,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  ScaleTransition(
                    scale: pulse,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C3A6A),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.add_to_drive_outlined,
                        color: Color(0xFF8EA7FF),
                        size: 27,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4F8DF7),
                        shape: BoxShape.circle,
                      ),
                      child: RotationTransition(
                        turns: controller,
                        child: const Icon(
                          Icons.sync,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: Color(0xFF9AAAD2),
                      fontSize: 12,
                      height: 1.35,
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
}
