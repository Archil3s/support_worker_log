import 'package:flutter/material.dart';

import '../utils/billing_rules.dart';
import '../utils/formatters.dart';
import 'app_settings.dart';
import 'entry_type.dart';

const supportNoteBreakdownTemplate = '''
Main topic(s)  (max. 200 words)
    1. 

Outcome(s)  (Max. 100 words)
    1. 

Next action(s)
    1.

Overall impression (Max. 150 words)
    1. 

Local referral tracking
    No referrals discussed or made this visit.

Safety concerns for sexual harm survivors and mental health
    No safety concerns noted.
''';

enum TextContactDirection { received, sent, exchange }

extension TextContactDirectionLabel on TextContactDirection {
  String get label {
    switch (this) {
      case TextContactDirection.received:
        return 'Text received';
      case TextContactDirection.sent:
        return 'Text sent';
      case TextContactDirection.exchange:
        return 'Text exchange';
    }
  }
}

bool _sameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

class NextActionItem {
  const NextActionItem({
    required this.id,
    required this.text,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final String text;
  final DateTime createdAt;
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  NextActionItem copyWith({
    String? id,
    String? text,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return NextActionItem(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory NextActionItem.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();

    return NextActionItem(
      id:
          json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      text: json['text'] as String? ?? '',
      createdAt: createdAt,
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
    );
  }
}

class WorkEntry {
  const WorkEntry({
    required this.id,
    required this.client,
    required this.type,
    required this.date,
    required this.startTime,
    required this.minutes,
    required this.notes,
    this.supportNoteBreakdown = '',
    this.nextActions = const [],
    this.googleCalendarEntered = false,
    this.importantText = false,
    this.textContactDirection = TextContactDirection.received,
    this.textReplyNeeded = false,
    this.odometerStart,
    this.odometerEnd,
  });

  final String id;
  final String client;
  final EntryType type;
  final DateTime date;
  final TimeOfDay startTime;
  final int minutes;
  final List<String> notes;
  final String supportNoteBreakdown;
  final List<NextActionItem> nextActions;
  final bool googleCalendarEntered;
  final bool importantText;
  final TextContactDirection textContactDirection;
  final bool textReplyNeeded;
  final double? odometerStart;
  final double? odometerEnd;

  int get baseMinutes => minutes.clamp(0, 1440).toInt();

  double get baseHours => baseMinutes / 60;

  BillingTimeBreakdown get billingTime {
    return calculateBillableTime(
      type: type,
      baseMinutes: baseMinutes,
      notes: notes,
    );
  }

  int get noteSeconds => billingTime.noteSeconds;

  double get noteHours => billingTime.noteHours;

  double get hours => billingTime.billableHours;

  String get noteAllowanceText => billingTime.noteAllowanceText;

  String get billableTimeText => billingTime.totalTimeText;

  double get kilometres {
    if (type != EntryType.homeVisit) return 0;
    if (odometerStart == null || odometerEnd == null) return 0;

    final value = odometerEnd! - odometerStart!;
    return value < 0 ? 0 : value;
  }

  bool hasSameCalendarEventDetails(WorkEntry other) {
    return client == other.client &&
        type == other.type &&
        _sameDate(date, other.date) &&
        startTime == other.startTime &&
        minutes == other.minutes &&
        hours == other.hours &&
        kilometres == other.kilometres &&
        importantText == other.importantText;
  }

  double earnings(AppSettings settings) {
    return hours * settings.hourlyRate;
  }

  double fuelReimbursement(AppSettings settings) {
    return kilometres * settings.fuelRate;
  }

  WorkEntry copyWith({
    String? id,
    String? client,
    EntryType? type,
    DateTime? date,
    TimeOfDay? startTime,
    int? minutes,
    List<String>? notes,
    String? supportNoteBreakdown,
    List<NextActionItem>? nextActions,
    bool? googleCalendarEntered,
    bool? importantText,
    TextContactDirection? textContactDirection,
    bool? textReplyNeeded,
    double? odometerStart,
    double? odometerEnd,
  }) {
    return WorkEntry(
      id: id ?? this.id,
      client: client ?? this.client,
      type: type ?? this.type,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      minutes: minutes ?? this.minutes,
      notes: notes ?? this.notes,
      supportNoteBreakdown: supportNoteBreakdown ?? this.supportNoteBreakdown,
      nextActions: nextActions ?? this.nextActions,
      googleCalendarEntered:
          googleCalendarEntered ?? this.googleCalendarEntered,
      importantText: importantText ?? this.importantText,
      textContactDirection: textContactDirection ?? this.textContactDirection,
      textReplyNeeded: textReplyNeeded ?? this.textReplyNeeded,
      odometerStart: odometerStart ?? this.odometerStart,
      odometerEnd: odometerEnd ?? this.odometerEnd,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client': client,
      'type': type.name,
      'date': date.toIso8601String(),
      'startHour': startTime.hour,
      'startMinute': startTime.minute,
      'minutes': minutes,
      'notes': notes,
      'supportNoteBreakdown': supportNoteBreakdown,
      'nextActions': nextActions.map((item) => item.toJson()).toList(),
      'googleCalendarEntered': googleCalendarEntered,
      'importantText': importantText,
      'textContactDirection': textContactDirection.name,
      'textReplyNeeded': textReplyNeeded,
      'odometerStart': odometerStart,
      'odometerEnd': odometerEnd,
    };
  }

  factory WorkEntry.fromJson(Map<String, dynamic> json) {
    int readInt(String key, int fallback) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return fallback;
    }

    double? readNullableDouble(String key) {
      final value = json[key];
      if (value is num) return value.toDouble();
      return null;
    }

    int boundInt(int value, int min, int max) {
      if (value < min) return min;
      if (value > max) return max;
      return value;
    }

    final typeName = json['type'] as String?;
    final type = EntryType.values.firstWhere(
      (entryType) => entryType.name == typeName,
      orElse: () => EntryType.homeVisit,
    );

    final dateText = json['date'] as String?;
    final parsedDate = DateTime.tryParse(dateText ?? '') ?? DateTime.now();

    final rawNotes = json['notes'];
    final notes = rawNotes is List
        ? rawNotes.whereType<String>().toList()
        : <String>[];

    final rawNextActions = json['nextActions'];
    final nextActions = rawNextActions is List
        ? rawNextActions
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .map(NextActionItem.fromJson)
              .where((item) => item.text.trim().isNotEmpty)
              .toList()
        : <NextActionItem>[];
    final textDirectionName = json['textContactDirection'] as String?;
    final textContactDirection = TextContactDirection.values.firstWhere(
      (direction) => direction.name == textDirectionName,
      orElse: () => TextContactDirection.received,
    );

    return WorkEntry(
      id:
          json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      client: json['client'] as String? ?? 'Unknown Client',
      type: type,
      date: parsedDate,
      startTime: TimeOfDay(
        hour: boundInt(readInt('startHour', 9), 0, 23),
        minute: boundInt(readInt('startMinute', 0), 0, 59),
      ),
      minutes: boundInt(readInt('minutes', 0), 0, 1440),
      notes: notes,
      supportNoteBreakdown: json['supportNoteBreakdown'] as String? ?? '',
      nextActions: nextActions,
      googleCalendarEntered: json['googleCalendarEntered'] == true,
      importantText: json['importantText'] == true,
      textContactDirection: textContactDirection,
      textReplyNeeded: json['textReplyNeeded'] == true,
      odometerStart: readNullableDouble('odometerStart'),
      odometerEnd: readNullableDouble('odometerEnd'),
    );
  }

  String textSummary(AppSettings settings) {
    final buffer = StringBuffer()
      ..writeln('$client - ${type.label}')
      ..writeln('Date: ${formatDate(date)}')
      ..writeln('Start: ${formatTime(startTime)}')
      ..writeln('Visit time: $baseMinutes min')
      ..writeln('Note time: ${billingTime.noteTimeText}')
      ..writeln('Billable time: ${hours.toStringAsFixed(2)} hrs')
      ..writeln('Earnings: ${money(earnings(settings))}');

    if (type == EntryType.homeVisit) {
      buffer
        ..writeln('KM: ${kilometres.toStringAsFixed(1)}')
        ..writeln('Fuel: ${money(fuelReimbursement(settings))}');
    }

    if (notes.isNotEmpty) {
      buffer.writeln('Notes: ${notes.join(', ')}');
    }

    if (supportNoteBreakdown.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(supportNoteBreakdown.trim());
    }

    if (googleCalendarEntered) {
      buffer
        ..writeln()
        ..writeln('Google Calendar: entered');
    }

    if (type == EntryType.textNote) {
      buffer
        ..writeln()
        ..writeln('Text direction: ${textContactDirection.label}')
        ..writeln('Text importance: ${importantText ? 'important' : 'normal'}')
        ..writeln('Reply needed: ${textReplyNeeded ? 'yes' : 'no'}');
    }

    if (nextActions.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Next actions:');

      for (final item in nextActions) {
        final status = item.completedAt == null
            ? 'open'
            : 'completed ${formatDate(item.completedAt!)}';

        buffer.writeln('- ${item.text} ($status)');
      }
    }

    return buffer.toString().trim();
  }
}
