import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/google_export_account_scope.dart';
import '../../core/state/app_state.dart';

class GoogleAccountSelector extends StatelessWidget {
  const GoogleAccountSelector({
    super.key,
    required this.scope,
    this.compact = false,
  });

  final GoogleExportAccountScope scope;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final emails = _emailsFor(appState);
    final preferred = appState.preferredGoogleAccountEmailForScope(scope);
    final selected = _selectedEmail(emails, preferred);

    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: '${scope.label} Google account',
        prefixIcon: const Icon(Icons.account_circle_outlined),
        helperText: emails.isEmpty
            ? 'Choose a Google account first.'
            : 'Used when this tab saves or syncs Google Drive files.',
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: compact ? 10 : 14,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      hint: const Text('No saved Google account'),
      items: [
        for (final email in emails)
          DropdownMenuItem<String>(
            value: email,
            child: Text(email, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: emails.isEmpty
          ? null
          : (email) {
              if (email == null) return;
              unawaited(_selectAccount(context, email));
            },
    );
  }

  List<String> _emailsFor(AppState appState) {
    final emails = <String>{
      ...appState.rememberedGoogleAccountEmails,
      if (appState.googleAccountEmailForScope(scope)?.trim().isNotEmpty == true)
        appState.googleAccountEmailForScope(scope)!.trim(),
      if (appState
              .preferredGoogleAccountEmailForScope(scope)
              ?.trim()
              .isNotEmpty ==
          true)
        appState.preferredGoogleAccountEmailForScope(scope)!.trim(),
    }.toList();

    emails.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return emails;
  }

  String? _selectedEmail(List<String> emails, String? preferred) {
    final cleaned = preferred?.trim();
    if (cleaned == null || cleaned.isEmpty) return null;

    for (final email in emails) {
      if (email.toLowerCase() == cleaned.toLowerCase()) return email;
    }

    return null;
  }

  Future<void> _selectAccount(BuildContext context, String email) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await context.read<AppState>().selectGoogleAccountForScope(
        scope: scope,
        email: email,
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${scope.label} Google account selected. Use Connect when you want to upload to Drive.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString().trim();
    if (text.startsWith('Bad state: ')) {
      return text.replaceFirst('Bad state: ', '').trim();
    }

    return text.isEmpty ? 'Could not select Google account.' : text;
  }
}
