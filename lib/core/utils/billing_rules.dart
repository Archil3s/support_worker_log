import '../models/entry_type.dart';

class BillingTimeBreakdown {
  const BillingTimeBreakdown({
    required this.baseMinutes,
    required this.noteSeconds,
  });

  final int baseMinutes;
  final int noteSeconds;

  int get baseSeconds => baseMinutes * 60;
  int get billableSeconds => baseSeconds + noteSeconds;

  double get baseHours => baseSeconds / 3600;
  double get noteHours => noteSeconds / 3600;
  double get billableHours => billableSeconds / 3600;

  String get baseTimeText => formatBillingSeconds(baseSeconds);
  String get noteTimeText => formatBillingSeconds(noteSeconds);
  String get totalTimeText => formatBillingSeconds(billableSeconds);

  String get noteAllowanceText {
    if (noteSeconds <= 0) return 'No note allowance';

    return '${formatBillingSeconds(noteSeconds)} note allowance';
  }
}

BillingTimeBreakdown calculateBillableTime({
  required EntryType type,
  required int baseMinutes,
  required Iterable<String> notes,
}) {
  final safeBaseMinutes = baseMinutes.clamp(0, 1440).toInt();
  final noteMinutes = noteAllowanceMinutes(safeBaseMinutes);

  return BillingTimeBreakdown(
    baseMinutes: safeBaseMinutes,
    noteSeconds: noteMinutes * 60,
  );
}

int noteAllowanceMinutes(int baseMinutes) {
  final safeBaseMinutes = baseMinutes.clamp(0, 1440).toInt();

  if (safeBaseMinutes >= 60) return 30;
  if (safeBaseMinutes > 30) return 15;

  return 0;
}

String formatBillingSeconds(int seconds) {
  final safeSeconds = seconds < 0 ? 0 : seconds;
  final hours = safeSeconds ~/ 3600;
  final minutes = (safeSeconds % 3600) ~/ 60;
  final remainingSeconds = safeSeconds % 60;

  if (hours > 0 && remainingSeconds > 0) {
    return '${hours}h ${minutes}m ${remainingSeconds}s';
  }

  if (hours > 0) {
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }

  if (minutes > 0 && remainingSeconds > 0) {
    return '${minutes}m ${remainingSeconds}s';
  }

  if (minutes > 0) {
    return '${minutes}m';
  }

  return '${remainingSeconds}s';
}
