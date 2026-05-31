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

Overall impression (Max. 150 words)
    1. 
''';

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

  int get noteSeconds => 0;

  double get noteHours => 0;

  double get hours => baseHours;

  String get noteAllowanceText => 'Manual notes only';

  String get billableTimeText => billingTime.totalTimeText;

  double get kilometres {
    if (type != EntryType.homeVisit) return 0;
    if (odometerStart == null || odometerEnd == null) return 0;

    final value = odometerEnd! - odometerStart!;
    return value < 0 ? 0 : value;
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
      odometerStart: readNullableDouble('odometerStart'),
      odometerEnd: readNullableDouble('odometerEnd'),
    );
  }

  String textSummary(AppSettings settings) {
    final buffer = StringBuffer()
      ..writeln('$client - ${type.label}')
      ..writeln('Date: ${formatDate(date)}')
      ..writeln('Start: ${formatTime(startTime)}')
      ..writeln('Time: $baseMinutes min (${hours.toStringAsFixed(2)} hrs)')
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

    return buffer.toString().trim();
  }
}
