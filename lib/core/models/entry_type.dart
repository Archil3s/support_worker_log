import 'package:flutter/material.dart';

enum EntryType {
  homeVisit,
  professionalContact,
  phoneCall,
  videoCall,
  emailClient,
  emailProfessional,
  adminEducationResources,
  textNote,
}

extension EntryTypeLabel on EntryType {
  String get label {
    switch (this) {
      case EntryType.homeVisit:
        return 'Home Visit';
      case EntryType.professionalContact:
        return 'Professional Contact';
      case EntryType.phoneCall:
        return 'Phone Call';
      case EntryType.videoCall:
        return 'Video Call';
      case EntryType.emailClient:
        return 'Email Client';
      case EntryType.emailProfessional:
        return 'Email Professional';
      case EntryType.adminEducationResources:
        return 'Admin / Education / Resources';
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
      case EntryType.videoCall:
        return Icons.video_call_outlined;
      case EntryType.emailClient:
        return Icons.alternate_email_outlined;
      case EntryType.emailProfessional:
        return Icons.mark_email_read_outlined;
      case EntryType.adminEducationResources:
        return Icons.menu_book_outlined;
      case EntryType.textNote:
        return Icons.sms_outlined;
    }
  }

  bool get isWrittenContact {
    switch (this) {
      case EntryType.emailClient:
      case EntryType.emailProfessional:
      case EntryType.textNote:
        return true;
      case EntryType.homeVisit:
      case EntryType.professionalContact:
      case EntryType.phoneCall:
      case EntryType.videoCall:
      case EntryType.adminEducationResources:
        return false;
    }
  }

  bool get workOnly {
    switch (this) {
      case EntryType.emailClient:
      case EntryType.emailProfessional:
      case EntryType.videoCall:
      case EntryType.adminEducationResources:
        return true;
      case EntryType.homeVisit:
      case EntryType.professionalContact:
      case EntryType.phoneCall:
      case EntryType.textNote:
        return false;
    }
  }

  bool get requiresClientSelection {
    switch (this) {
      case EntryType.emailProfessional:
      case EntryType.adminEducationResources:
        return false;
      case EntryType.homeVisit:
      case EntryType.professionalContact:
      case EntryType.phoneCall:
      case EntryType.videoCall:
      case EntryType.emailClient:
      case EntryType.textNote:
        return true;
    }
  }

  bool get allowsOptionalClientTag {
    return this == EntryType.adminEducationResources;
  }

  String get fallbackClientName {
    switch (this) {
      case EntryType.emailProfessional:
        return 'Professional email';
      case EntryType.adminEducationResources:
        return 'Admin / Education / Resources';
      case EntryType.homeVisit:
      case EntryType.professionalContact:
      case EntryType.phoneCall:
      case EntryType.videoCall:
      case EntryType.emailClient:
      case EntryType.textNote:
        return 'Unknown Client';
    }
  }
}

List<EntryType> entryTypesForMode({required bool payeMode}) {
  if (!payeMode) return EntryType.values;
  return EntryType.values.where((type) => !type.workOnly).toList();
}
