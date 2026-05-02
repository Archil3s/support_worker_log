import 'package:flutter/material.dart';

import 'entry_type.dart';

class ActiveVisit {
  const ActiveVisit({
    required this.id,
    required this.client,
    required this.type,
    required this.startedAt,
    this.odometerStart,
    this.notes = const [],
  });

  final String id;
  final String client;
  final EntryType type;
  final DateTime startedAt;
  final double? odometerStart;
  final List<String> notes;

  ActiveVisit copyWith({
    String? id,
    String? client,
    EntryType? type,
    DateTime? startedAt,
    double? odometerStart,
    List<String>? notes,
  }) {
    return ActiveVisit(
      id: id ?? this.id,
      client: client ?? this.client,
      type: type ?? this.type,
      startedAt: startedAt ?? this.startedAt,
      odometerStart: odometerStart ?? this.odometerStart,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client': client,
      'type': type.name,
      'startedAt': startedAt.toIso8601String(),
      'odometerStart': odometerStart,
      'notes': notes,
    };
  }

  factory ActiveVisit.fromJson(Map<String, dynamic> json) {
    double? readNullableDouble(String key) {
      final value = json[key];
      if (value is num) return value.toDouble();
      return null;
    }

    final typeName = json['type'] as String?;
    final type = EntryType.values.firstWhere(
      (entryType) => entryType.name == typeName,
      orElse: () => EntryType.homeVisit,
    );

    final startedAtText = json['startedAt'] as String?;
    final startedAt = DateTime.tryParse(startedAtText ?? '') ?? DateTime.now();

    final rawNotes = json['notes'];
    final notes = rawNotes is List
        ? rawNotes.whereType<String>().toList()
        : <String>[];

    return ActiveVisit(
      id:
          json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      client: json['client'] as String? ?? 'Unknown Client',
      type: type,
      startedAt: startedAt,
      odometerStart: readNullableDouble('odometerStart'),
      notes: notes,
    );
  }

  TimeOfDay get startTime => TimeOfDay.fromDateTime(startedAt);

  DateTime get dateOnly {
    return DateTime(startedAt.year, startedAt.month, startedAt.day);
  }
}
