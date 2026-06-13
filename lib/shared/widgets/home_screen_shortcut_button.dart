import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/web_install_prompt_service.dart';

class HomeScreenShortcutButton extends StatelessWidget {
  const HomeScreenShortcutButton({
    super.key,
    required this.title,
    required this.mode,
    required this.icon,
  });

  final String title;
  final String mode;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _installOrShowShortcutSheet(context),
      icon: Icon(icon),
      label: Text('Add $title to phone screen'),
    );
  }

  Future<void> _installOrShowShortcutSheet(BuildContext context) async {
    final installed = await WebInstallPromptService().promptInstall();
    if (!context.mounted) return;

    if (installed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$title install prompt opened.')));
      return;
    }

    await _showShortcutSheet(context);
  }

  Future<void> _showShortcutSheet(BuildContext context) {
    final url = _shortcutUrl().toString();
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add $title',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'iPhone does not let a web app create the Home Screen icon '
                  'by itself. Open the shortcut page, tap Share, then Add to '
                  'Home Screen.',
                  style: TextStyle(color: Color(0xFFCDD7F0), height: 1.35),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _openShortcutPage(context),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open shortcut page'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _copyShortcut(context, url),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy shortcut link'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Uri _shortcutUrl() {
    final base = Uri.base;
    final query = Map<String, String>.from(base.queryParameters);
    query['mode'] = mode;
    return base.replace(queryParameters: query, fragment: '');
  }

  Future<void> _openShortcutPage(BuildContext context) async {
    final opened = await launchUrl(
      _shortcutUrl(),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open shortcut page.')),
      );
    }
  }

  Future<void> _copyShortcut(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Shortcut link copied.')));
  }
}
