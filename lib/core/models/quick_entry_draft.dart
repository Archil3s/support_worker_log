import 'package:flutter/material.dart';

import 'entry_type.dart';

class QuickEntryDraft {
  const QuickEntryDraft({
    required this.selectedClient,
    required this.selectedType,
    required this.selectedDate,
    required this.startTime,
    required this.baseMinutes,
    required this.textCount,
    required this.selectedNotes,
    required this.odometerStart,
    required this.odometerEnd,
  });

  final String? selectedClient;
  final EntryType selectedType;
  final DateTime selectedDate;
  final TimeOfDay startTime;
  final int baseMinutes;
  final int textCount;
  final List<String> selectedNotes;
  final String odometerStart;
  final String odometerEnd;

  Map<String, dynamic> toJson() {
    return {
      'selectedClient': selectedClient,
      'selectedType': selectedType.name,
      'selectedDate': selectedDate.toIso8601String(),
      'startHour': startTime.hour,
      'startMinute': startTime.minute,
      'baseMinutes': baseMinutes,
      'textCount': textCount,
      'selectedNotes': selectedNotes,
      'odometerStart': odometerStart,
      'odometerEnd': odometerEnd,
    };
  }

  factory QuickEntryDraft.fromJson(Map<String, dynamic> json) {
    int readInt(String key, int fallback) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return fallback;
    }

    int boundInt(int value, int min, int max) {
      if (value < min) return min;
      if (value > max) return max;
      return value;
    }

    final typeName = json['selectedType'] as String?;
    final selectedType = EntryType.values.firstWhere(
      (type) => type.name == typeName,
      orElse: () => EntryType.homeVisit,
    );

    final dateText = json['selectedDate'] as String?;
    final selectedDate = DateTime.tryParse(dateText ?? '') ?? DateTime.now();

    final rawNotes = json['selectedNotes'];
    final selectedNotes = rawNotes is List
        ? rawNotes.whereType<String>().toList()
        : <String>[];

    return QuickEntryDraft(
      selectedClient: json['selectedClient'] as String?,
      selectedType: selectedType,
      selectedDate: selectedDate,
      startTime: TimeOfDay(
        hour: boundInt(readInt('startHour', 9), 0, 23),
        minute: boundInt(readInt('startMinute', 0), 0, 59),
      ),
      baseMinutes: boundInt(readInt('baseMinutes', 60), 5, 1440),
      textCount: boundInt(readInt('textCount', 1), 1, 1000),
      selectedNotes: selectedNotes,
      odometerStart: json['odometerStart'] as String? ?? '',
      odometerEnd: json['odometerEnd'] as String? ?? '',
    );
  }
}
