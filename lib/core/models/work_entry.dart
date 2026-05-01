import 'package:flutter/material.dart';

import '../utils/formatters.dart';
import 'app_settings.dart';
import 'entry_type.dart';

class WorkEntry {
  const WorkEntry({
    required this.id,
    required this.client,
    required this.type,
    required this.date,
    required this.startTime,
    required this.minutes,
    required this.notes,
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
  final double? odometerStart;
  final double? odometerEnd;

  double get hours => minutes / 60;

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
      odometerStart: odometerStart ?? this.odometerStart,
      odometerEnd: odometerEnd ?? this.odometerEnd,
    );
  }

  String textSummary(AppSettings settings) {
    final buffer = StringBuffer()
      ..writeln('$client - ${type.label}')
      ..writeln('Date: ${formatDate(date)}')
      ..writeln('Start: ${formatTime(startTime)}')
      ..writeln('Time: $minutes min (${hours.toStringAsFixed(2)} hrs)')
      ..writeln('Earnings: ${money(earnings(settings))}');

    if (type == EntryType.homeVisit) {
      buffer
        ..writeln('KM: ${kilometres.toStringAsFixed(1)}')
        ..writeln('Fuel: ${money(fuelReimbursement(settings))}');
    }

    if (notes.isNotEmpty) {
      buffer.writeln('Notes: ${notes.join(', ')}');
    }

    return buffer.toString().trim();
  }
}
