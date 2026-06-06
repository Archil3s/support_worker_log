import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/core/models/app_settings.dart';

void main() {
  test('persists Google Drive folder ids', () {
    final settings = const AppSettings().copyWith(
      googleDriveRootFolderId: 'root',
      googleDriveTemplatesFolderId: 'templates',
      googleDriveClientNotesFolderId: 'client-notes',
      googleDriveCalendarExportsFolderId: 'calendar-exports',
      googleDriveInvoicesFolderId: 'invoices',
      googleDriveReferralsFolderId: 'referrals',
      googleDrivePersonalNotesFolderId: 'personal-notes',
      googleWorkAccountEmail: 'work@example.com',
      googlePersonalAccountEmail: 'personal@example.com',
      personalGoogleDriveRootFolderId: 'personal-root',
      personalGoogleDrivePersonalNotesFolderId: 'personal-drive-notes',
    );

    final restored = AppSettings.fromJson(settings.toJson());

    expect(restored.googleDriveRootFolderId, 'root');
    expect(restored.googleDriveTemplatesFolderId, 'templates');
    expect(restored.googleDriveClientNotesFolderId, 'client-notes');
    expect(restored.googleDriveCalendarExportsFolderId, 'calendar-exports');
    expect(restored.googleDriveInvoicesFolderId, 'invoices');
    expect(restored.googleDriveReferralsFolderId, 'referrals');
    expect(restored.googleDrivePersonalNotesFolderId, 'personal-notes');
    expect(restored.googleWorkAccountEmail, 'work@example.com');
    expect(restored.googlePersonalAccountEmail, 'personal@example.com');
    expect(restored.personalGoogleDriveRootFolderId, 'personal-root');
    expect(
      restored.personalGoogleDrivePersonalNotesFolderId,
      'personal-drive-notes',
    );
  });
}
