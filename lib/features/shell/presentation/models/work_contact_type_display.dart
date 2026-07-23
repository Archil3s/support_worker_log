import '../../../../core/models/entry_type.dart';

const workContactTypeDisplayOrder = [
  EntryType.homeVisit,
  EntryType.professionalContact,
  EntryType.textNote,
  EntryType.phoneCall,
  EntryType.videoCall,
  EntryType.emailClient,
  EntryType.emailProfessional,
  EntryType.adminEducationResources,
];

String workContactTypeDisplayLabel(EntryType type) {
  switch (type) {
    case EntryType.homeVisit:
      return 'Home visits';
    case EntryType.professionalContact:
      return 'Professional contacts';
    case EntryType.textNote:
      return 'Texts';
    case EntryType.phoneCall:
      return 'Phone calls';
    case EntryType.videoCall:
      return 'Video calls';
    case EntryType.emailClient:
      return 'Client emails';
    case EntryType.emailProfessional:
      return 'Professional emails';
    case EntryType.adminEducationResources:
      return 'Admin / resources';
  }
}
