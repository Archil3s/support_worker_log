import '../../../../core/models/personal_log_entry.dart';
import '../../domain/entities/mood_check_in.dart';

class MoodCheckInModel {
  const MoodCheckInModel(this.entity);

  static const titlePrefix = 'Mood Tracker: ';
  static const legacyTitlePrefix = 'Mood & Testosterone: ';
  static const metricPrefix = 'mood_tracker_v1';

  final MoodCheckIn entity;

  PersonalLogEntry toPersonalLogEntry() {
    final feelingValues = [
      for (final feeling in MoodFeeling.values)
        '${feeling.name}=${entity.feelings[feeling] ?? 0}',
    ];
    final metric = [
      metricPrefix,
      'gel=${entity.gelTiming.name}',
      'dose=${entity.recentDoseChange ? 1 : 0}',
      'stress=${entity.stress}',
      'sleep=${entity.sleepQuality}',
      'event=${entity.notableEvent ? 1 : 0}',
      if (entity.phq9Score != null) 'phq9=${entity.phq9Score}',
      if (entity.gad7Score != null) 'gad7=${entity.gad7Score}',
      ...feelingValues,
    ].join('|');

    return PersonalLogEntry(
      id: entity.id,
      category: PersonalLogCategory.health,
      date: entity.date,
      title: '$titlePrefix${_headline(entity)}',
      metric: metric,
      notes: entity.notes,
    );
  }

  static MoodCheckIn? fromPersonalLogEntry(PersonalLogEntry entry) {
    if ((!entry.title.startsWith(titlePrefix) &&
            !entry.title.startsWith(legacyTitlePrefix)) ||
        !entry.metric.startsWith(metricPrefix)) {
      return null;
    }

    final values = <String, String>{};
    for (final part in entry.metric.split('|').skip(1)) {
      final separator = part.indexOf('=');
      if (separator <= 0) continue;
      values[part.substring(0, separator)] = part.substring(separator + 1);
    }

    final gelTiming = GelTiming.values.firstWhere(
      (timing) => timing.name == values['gel'],
      orElse: () => GelTiming.before,
    );
    final feelings = {
      for (final feeling in MoodFeeling.values)
        feeling: int.tryParse(values[feeling.name] ?? '') ?? 0,
    };

    return MoodCheckIn(
      id: entry.id,
      date: entry.date,
      gelTiming: gelTiming,
      recentDoseChange: values['dose'] == '1',
      stress: int.tryParse(values['stress'] ?? '') ?? 0,
      sleepQuality: int.tryParse(values['sleep'] ?? '') ?? 0,
      notableEvent: values['event'] == '1',
      feelings: feelings,
      notes: entry.notes,
      phq9Score: int.tryParse(values['phq9'] ?? ''),
      gad7Score: int.tryParse(values['gad7'] ?? ''),
    );
  }

  static bool isMoodEntry(PersonalLogEntry entry) {
    return entry.title.startsWith(titlePrefix) ||
        entry.title.startsWith(legacyTitlePrefix);
  }

  static String _headline(MoodCheckIn checkIn) {
    final strongest = checkIn.feelings.entries.reduce(
      (current, next) => next.value > current.value ? next : current,
    );
    return '${strongest.key.label} ${strongest.value}/5';
  }
}
