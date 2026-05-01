import 'package:flutter/material.dart';

enum EntryType { homeVisit, professionalContact, phoneCall, textNote }

extension EntryTypeLabel on EntryType {
  String get label {
    switch (this) {
      case EntryType.homeVisit:
        return 'Home Visit';
      case EntryType.professionalContact:
        return 'Professional Contact';
      case EntryType.phoneCall:
        return 'Phone Call';
      case EntryType.textNote:
        return 'Text Note';
    }
  }

  IconData get icon {
    switch (this) {
      case EntryType.homeVisit:
        return Icons.home_work_outlined;
      case EntryType.professionalContact:
        return Icons.handshake_outlined;
      case EntryType.phoneCall:
        return Icons.phone_outlined;
      case EntryType.textNote:
        return Icons.sms_outlined;
    }
  }
}
