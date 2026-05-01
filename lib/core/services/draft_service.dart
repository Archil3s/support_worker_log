import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/quick_entry_draft.dart';

class DraftService {
  static const _draftKey = 'support_worker_log_quick_entry_draft_v1';

  Future<QuickEntryDraft?> loadQuickEntryDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final source = prefs.getString(_draftKey);

    if (source == null || source.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(source);

    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return QuickEntryDraft.fromJson(decoded);
  }

  Future<void> saveQuickEntryDraft(QuickEntryDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(draft.toJson()));
  }

  Future<void> clearQuickEntryDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }
}
