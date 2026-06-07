class AppSettings {
  const AppSettings({
    this.hourlyRate = 43,
    this.fuelRate = 1.17,
    this.accRate = 0.017,
    this.gstRate = 0.15,
    this.kiwiSaverEnabled = false,
    this.kiwiSaverRate = 0.03,
    this.noteOptions = defaultNoteOptions,
    this.payPeriodAnchorDate,
    this.weeklyHoursGoal = 10,
    this.weeklyEarningsGoal = 1000,
    this.googleDriveRootFolderId,
    this.googleDriveTemplatesFolderId,
    this.googleDriveClientNotesFolderId,
    this.googleDriveCalendarExportsFolderId,
    this.googleDriveInvoicesFolderId,
    this.googleDriveReferralsFolderId,
    this.googleDrivePersonalNotesFolderId,
    this.googleWorkAccountEmail,
    this.googlePersonalAccountEmail,
    this.googlePayeAccountEmail,
    this.payeGoogleDriveRootFolderId,
    this.payeGoogleDriveNotesFolderId,
    this.personalGoogleDriveRootFolderId,
    this.personalGoogleDrivePersonalNotesFolderId,
  });

  static const defaultNoteOptions = [
    'Wellbeing',
    'Safety Plan',
    'Distress Support',
    'Daily Living',
    'Appointment',
    'Transport',
    'Advocacy',
    'Crisis',
    'Trauma Support',
    'Boundaries',
    'Family/Tamariki',
    'Community',
    'Prof. Contact',
    'No Contact',
    'Cancelled',
    'No Show',
    'Rescheduled',
    'Client Rescheduled',
    'Late Cancel',
    'Cut Short',
    'Follow-up Needed',
  ];

  final double hourlyRate;
  final double fuelRate;
  final double accRate;
  final double gstRate;
  final bool kiwiSaverEnabled;
  final double kiwiSaverRate;
  final List<String> noteOptions;
  final DateTime? payPeriodAnchorDate;
  final double weeklyHoursGoal;
  final double weeklyEarningsGoal;
  final String? googleDriveRootFolderId;
  final String? googleDriveTemplatesFolderId;
  final String? googleDriveClientNotesFolderId;
  final String? googleDriveCalendarExportsFolderId;
  final String? googleDriveInvoicesFolderId;
  final String? googleDriveReferralsFolderId;
  final String? googleDrivePersonalNotesFolderId;
  final String? googleWorkAccountEmail;
  final String? googlePersonalAccountEmail;
  final String? googlePayeAccountEmail;
  final String? payeGoogleDriveRootFolderId;
  final String? payeGoogleDriveNotesFolderId;
  final String? personalGoogleDriveRootFolderId;
  final String? personalGoogleDrivePersonalNotesFolderId;

  AppSettings copyWith({
    double? hourlyRate,
    double? fuelRate,
    double? accRate,
    double? gstRate,
    bool? kiwiSaverEnabled,
    double? kiwiSaverRate,
    List<String>? noteOptions,
    DateTime? payPeriodAnchorDate,
    bool clearPayPeriodAnchorDate = false,
    double? weeklyHoursGoal,
    double? weeklyEarningsGoal,
    String? googleDriveRootFolderId,
    String? googleDriveTemplatesFolderId,
    String? googleDriveClientNotesFolderId,
    String? googleDriveCalendarExportsFolderId,
    String? googleDriveInvoicesFolderId,
    String? googleDriveReferralsFolderId,
    String? googleDrivePersonalNotesFolderId,
    String? googleWorkAccountEmail,
    String? googlePersonalAccountEmail,
    String? googlePayeAccountEmail,
    String? payeGoogleDriveRootFolderId,
    String? payeGoogleDriveNotesFolderId,
    String? personalGoogleDriveRootFolderId,
    String? personalGoogleDrivePersonalNotesFolderId,
    bool clearGoogleDriveFolders = false,
    bool clearPersonalGoogleDriveFolders = false,
    bool clearPayeGoogleDriveFolders = false,
  }) {
    return AppSettings(
      hourlyRate: hourlyRate ?? this.hourlyRate,
      fuelRate: fuelRate ?? this.fuelRate,
      accRate: accRate ?? this.accRate,
      gstRate: gstRate ?? this.gstRate,
      kiwiSaverEnabled: kiwiSaverEnabled ?? this.kiwiSaverEnabled,
      kiwiSaverRate: kiwiSaverRate ?? this.kiwiSaverRate,
      noteOptions: noteOptions ?? this.noteOptions,
      payPeriodAnchorDate: clearPayPeriodAnchorDate
          ? null
          : payPeriodAnchorDate ?? this.payPeriodAnchorDate,
      weeklyHoursGoal: weeklyHoursGoal ?? this.weeklyHoursGoal,
      weeklyEarningsGoal: weeklyEarningsGoal ?? this.weeklyEarningsGoal,
      googleDriveRootFolderId: clearGoogleDriveFolders
          ? null
          : googleDriveRootFolderId ?? this.googleDriveRootFolderId,
      googleDriveTemplatesFolderId: clearGoogleDriveFolders
          ? null
          : googleDriveTemplatesFolderId ?? this.googleDriveTemplatesFolderId,
      googleDriveClientNotesFolderId: clearGoogleDriveFolders
          ? null
          : googleDriveClientNotesFolderId ??
                this.googleDriveClientNotesFolderId,
      googleDriveCalendarExportsFolderId: clearGoogleDriveFolders
          ? null
          : googleDriveCalendarExportsFolderId ??
                this.googleDriveCalendarExportsFolderId,
      googleDriveInvoicesFolderId: clearGoogleDriveFolders
          ? null
          : googleDriveInvoicesFolderId ?? this.googleDriveInvoicesFolderId,
      googleDriveReferralsFolderId: clearGoogleDriveFolders
          ? null
          : googleDriveReferralsFolderId ?? this.googleDriveReferralsFolderId,
      googleDrivePersonalNotesFolderId: clearGoogleDriveFolders
          ? null
          : googleDrivePersonalNotesFolderId ??
                this.googleDrivePersonalNotesFolderId,
      googleWorkAccountEmail:
          googleWorkAccountEmail ?? this.googleWorkAccountEmail,
      googlePersonalAccountEmail:
          googlePersonalAccountEmail ?? this.googlePersonalAccountEmail,
      googlePayeAccountEmail:
          googlePayeAccountEmail ?? this.googlePayeAccountEmail,
      payeGoogleDriveRootFolderId: clearPayeGoogleDriveFolders
          ? null
          : payeGoogleDriveRootFolderId ?? this.payeGoogleDriveRootFolderId,
      payeGoogleDriveNotesFolderId: clearPayeGoogleDriveFolders
          ? null
          : payeGoogleDriveNotesFolderId ?? this.payeGoogleDriveNotesFolderId,
      personalGoogleDriveRootFolderId: clearPersonalGoogleDriveFolders
          ? null
          : personalGoogleDriveRootFolderId ??
                this.personalGoogleDriveRootFolderId,
      personalGoogleDrivePersonalNotesFolderId: clearPersonalGoogleDriveFolders
          ? null
          : personalGoogleDrivePersonalNotesFolderId ??
                this.personalGoogleDrivePersonalNotesFolderId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hourlyRate': hourlyRate,
      'fuelRate': fuelRate,
      'accRate': accRate,
      'gstRate': gstRate,
      'kiwiSaverEnabled': kiwiSaverEnabled,
      'kiwiSaverRate': kiwiSaverRate,
      'noteOptions': noteOptions,
      'payPeriodAnchorDate': payPeriodAnchorDate?.toIso8601String(),
      'weeklyHoursGoal': weeklyHoursGoal,
      'weeklyEarningsGoal': weeklyEarningsGoal,
      'googleDriveRootFolderId': googleDriveRootFolderId,
      'googleDriveTemplatesFolderId': googleDriveTemplatesFolderId,
      'googleDriveClientNotesFolderId': googleDriveClientNotesFolderId,
      'googleDriveCalendarExportsFolderId': googleDriveCalendarExportsFolderId,
      'googleDriveInvoicesFolderId': googleDriveInvoicesFolderId,
      'googleDriveReferralsFolderId': googleDriveReferralsFolderId,
      'googleDrivePersonalNotesFolderId': googleDrivePersonalNotesFolderId,
      'googleWorkAccountEmail': googleWorkAccountEmail,
      'googlePersonalAccountEmail': googlePersonalAccountEmail,
      'googlePayeAccountEmail': googlePayeAccountEmail,
      'payeGoogleDriveRootFolderId': payeGoogleDriveRootFolderId,
      'payeGoogleDriveNotesFolderId': payeGoogleDriveNotesFolderId,
      'personalGoogleDriveRootFolderId': personalGoogleDriveRootFolderId,
      'personalGoogleDrivePersonalNotesFolderId':
          personalGoogleDrivePersonalNotesFolderId,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    double readDouble(String key, double fallback) {
      final value = json[key];
      if (value is num) return value.toDouble();
      return fallback;
    }

    bool readBool(String key, bool fallback) {
      final value = json[key];
      if (value is bool) return value;
      return fallback;
    }

    List<String> readNotes() {
      final value = json['noteOptions'];
      if (value is! List) return defaultNoteOptions;

      final notes = value
          .whereType<String>()
          .map((note) => note.trim())
          .where((note) => note.isNotEmpty)
          .toSet()
          .toList();

      return notes.isEmpty ? defaultNoteOptions : notes;
    }

    DateTime? readDate(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) return null;
      return DateTime.tryParse(value);
    }

    String? readString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) return null;
      return value.trim();
    }

    return AppSettings(
      hourlyRate: readDouble('hourlyRate', 43),
      fuelRate: readDouble('fuelRate', 1.17),
      accRate: readDouble('accRate', 0.017),
      gstRate: readDouble('gstRate', 0.15),
      kiwiSaverEnabled: readBool('kiwiSaverEnabled', false),
      kiwiSaverRate: readDouble('kiwiSaverRate', 0.03),
      noteOptions: readNotes(),
      payPeriodAnchorDate: readDate('payPeriodAnchorDate'),
      weeklyHoursGoal: readDouble('weeklyHoursGoal', 10),
      weeklyEarningsGoal: readDouble('weeklyEarningsGoal', 1000),
      googleDriveRootFolderId: readString('googleDriveRootFolderId'),
      googleDriveTemplatesFolderId: readString('googleDriveTemplatesFolderId'),
      googleDriveClientNotesFolderId: readString(
        'googleDriveClientNotesFolderId',
      ),
      googleDriveCalendarExportsFolderId: readString(
        'googleDriveCalendarExportsFolderId',
      ),
      googleDriveInvoicesFolderId: readString('googleDriveInvoicesFolderId'),
      googleDriveReferralsFolderId: readString('googleDriveReferralsFolderId'),
      googleDrivePersonalNotesFolderId: readString(
        'googleDrivePersonalNotesFolderId',
      ),
      googleWorkAccountEmail: readString('googleWorkAccountEmail'),
      googlePersonalAccountEmail: readString('googlePersonalAccountEmail'),
      googlePayeAccountEmail: readString('googlePayeAccountEmail'),
      payeGoogleDriveRootFolderId: readString('payeGoogleDriveRootFolderId'),
      payeGoogleDriveNotesFolderId: readString('payeGoogleDriveNotesFolderId'),
      personalGoogleDriveRootFolderId: readString(
        'personalGoogleDriveRootFolderId',
      ),
      personalGoogleDrivePersonalNotesFolderId: readString(
        'personalGoogleDrivePersonalNotesFolderId',
      ),
    );
  }
}
