import 'package:flutter/material.dart';

class ParsedInvoiceRow {
  const ParsedInvoiceRow({
    required this.sourceLine,
    required this.client,
    required this.date,
    required this.startTime,
    required this.minutes,
    required this.kilometres,
    required this.notes,
    required this.warnings,
  });

  final String sourceLine;
  final String client;
  final DateTime? date;
  final TimeOfDay startTime;
  final int minutes;
  final double kilometres;
  final List<String> notes;
  final List<String> warnings;

  bool get isValid => client.trim().isNotEmpty && date != null && minutes > 0;
}

List<ParsedInvoiceRow> parseInvoiceRows(String input) {
  final lines = input
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .where((line) {
        final lower = line.toLowerCase();
        return !(lower.contains('client') &&
            lower.contains('date') &&
            (lower.contains('km') || lower.contains('time')));
      })
      .toList();

  return [for (final line in lines) _parseLine(line)];
}

ParsedInvoiceRow _parseLine(String line) {
  final warnings = <String>[];
  final date = _parseDate(line);
  final client = _parseClient(line, date);

  final timeRange = _parseTimeRange(line);
  final durationMinutes = _parseDurationMinutes(line);

  final startTime = timeRange?.start ?? const TimeOfDay(hour: 9, minute: 0);
  final minutes = timeRange?.minutes ?? durationMinutes ?? 60;

  if (date == null) warnings.add('Date not recognised');
  if (client.trim().isEmpty) warnings.add('Client not recognised');
  if (timeRange == null && durationMinutes == null) {
    warnings.add('No time found, defaulted to 60 minutes');
  }

  final kilometres = _parseKilometres(line);
  final notes = _parseNotes(line);

  return ParsedInvoiceRow(
    sourceLine: line,
    client: client,
    date: date,
    startTime: startTime,
    minutes: minutes.clamp(1, 1440).toInt(),
    kilometres: kilometres,
    notes: notes,
    warnings: warnings,
  );
}

String _parseClient(String line, DateTime? date) {
  final parts = line
      .split(RegExp(r'[,|\t]'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isNotEmpty) return parts.first;

  final dateMatch = RegExp(
    r'(\d{4}-\d{1,2}-\d{1,2}|\d{1,2}[/-]\d{1,2}(?:[/-]\d{2,4})?)',
  ).firstMatch(line);

  if (dateMatch != null && dateMatch.start > 0) {
    return line.substring(0, dateMatch.start).trim();
  }

  return '';
}

DateTime? _parseDate(String line) {
  final iso = RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b').firstMatch(line);
  if (iso != null) {
    return DateTime.tryParse(
      '${iso.group(1)!}-${iso.group(2)!.padLeft(2, '0')}-${iso.group(3)!.padLeft(2, '0')}',
    );
  }

  final local = RegExp(
    r'\b(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?\b',
  ).firstMatch(line);

  if (local == null) return null;

  final day = int.tryParse(local.group(1)!);
  final month = int.tryParse(local.group(2)!);
  final rawYear = local.group(3);
  final now = DateTime.now();

  var year = rawYear == null ? now.year : int.tryParse(rawYear);
  if (year == null || day == null || month == null) return null;
  if (year < 100) year += 2000;

  if (month < 1 || month > 12 || day < 1 || day > 31) return null;

  return DateTime(year, month, day);
}

_ParsedTimeRange? _parseTimeRange(String line) {
  final match = RegExp(
    r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s*(?:-|to|–|—)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b',
    caseSensitive: false,
  ).firstMatch(line);

  if (match == null) return null;

  final startHour = int.tryParse(match.group(1)!);
  final startMinute = int.tryParse(match.group(2) ?? '0') ?? 0;
  final endHour = int.tryParse(match.group(4)!);
  final endMinute = int.tryParse(match.group(5) ?? '0') ?? 0;

  if (startHour == null || endHour == null) return null;

  final start = TimeOfDay(
    hour: _normaliseHour(startHour, match.group(3)),
    minute: startMinute.clamp(0, 59).toInt(),
  );

  final end = TimeOfDay(
    hour: _normaliseHour(endHour, match.group(6) ?? match.group(3)),
    minute: endMinute.clamp(0, 59).toInt(),
  );

  var startTotal = start.hour * 60 + start.minute;
  var endTotal = end.hour * 60 + end.minute;

  if (endTotal <= startTotal) endTotal += 1440;

  return _ParsedTimeRange(
    start: start,
    minutes: (endTotal - startTotal).clamp(1, 1440).toInt(),
  );
}

int _normaliseHour(int hour, String? marker) {
  var value = hour.clamp(0, 23).toInt();
  final lower = marker?.toLowerCase();

  if (lower == 'pm' && value < 12) value += 12;
  if (lower == 'am' && value == 12) value = 0;

  return value.clamp(0, 23).toInt();
}

int? _parseDurationMinutes(String line) {
  final hoursMatch = RegExp(
    r'\b(\d+(?:\.\d+)?)\s*(h|hr|hrs|hour|hours)\b',
    caseSensitive: false,
  ).firstMatch(line);

  final minutesMatch = RegExp(
    r'\b(\d+)\s*(m|min|mins|minute|minutes)\b',
    caseSensitive: false,
  ).firstMatch(line);

  var total = 0;

  if (hoursMatch != null) {
    final hours = double.tryParse(hoursMatch.group(1)!);
    if (hours != null) total += (hours * 60).round();
  }

  if (minutesMatch != null) {
    final minutes = int.tryParse(minutesMatch.group(1)!);
    if (minutes != null) total += minutes;
  }

  return total <= 0 ? null : total;
}

double _parseKilometres(String line) {
  final match = RegExp(
    r'\b(\d+(?:\.\d+)?)\s*(km|kms|kilometre|kilometres)\b',
    caseSensitive: false,
  ).firstMatch(line);

  if (match == null) return 0;

  return double.tryParse(match.group(1)!) ?? 0;
}

List<String> _parseNotes(String line) {
  final parts = line
      .split(RegExp(r'[,|\t]'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.length <= 4) return const [];

  return [
    parts.sublist(4).join(' ').trim(),
  ].where((note) => note.isNotEmpty).toList();
}

class _ParsedTimeRange {
  const _ParsedTimeRange({required this.start, required this.minutes});

  final TimeOfDay start;
  final int minutes;
}
