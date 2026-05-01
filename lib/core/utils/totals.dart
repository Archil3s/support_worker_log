import '../models/app_settings.dart';
import '../models/work_entry.dart';

double totalHours(Iterable<WorkEntry> entries) {
  return entries.fold<double>(0, (sum, entry) => sum + entry.hours);
}

double totalEarnings(Iterable<WorkEntry> entries, AppSettings settings) {
  return entries.fold<double>(
    0,
    (sum, entry) => sum + entry.earnings(settings),
  );
}

double totalKilometres(Iterable<WorkEntry> entries) {
  return entries.fold<double>(0, (sum, entry) => sum + entry.kilometres);
}
