enum GelTiming { before, after0To4, after4To8, after8To16, after16Plus, missed }

extension GelTimingLabel on GelTiming {
  String get label {
    return switch (this) {
      GelTiming.before => 'Before today\'s gel',
      GelTiming.after0To4 => '0-4 hours after gel',
      GelTiming.after4To8 => '4-8 hours after gel',
      GelTiming.after8To16 => '8-16 hours after gel',
      GelTiming.after16Plus => '16+ hours after gel',
      GelTiming.missed => 'Missed / not applied',
    };
  }

  double get proximityScore {
    return switch (this) {
      GelTiming.after0To4 => 5,
      GelTiming.after4To8 => 4,
      GelTiming.after8To16 => 2.5,
      GelTiming.after16Plus => 1,
      GelTiming.before || GelTiming.missed => 0,
    };
  }
}

enum MoodFeeling { calm, upbeat, energised, irritable, anxious, low, sensitive }

extension MoodFeelingLabel on MoodFeeling {
  String get label {
    return switch (this) {
      MoodFeeling.calm => 'Calm',
      MoodFeeling.upbeat => 'Upbeat',
      MoodFeeling.energised => 'Energised',
      MoodFeeling.irritable => 'Irritable',
      MoodFeeling.anxious => 'Anxious / restless',
      MoodFeeling.low => 'Low / flat',
      MoodFeeling.sensitive => 'Emotionally sensitive',
    };
  }

  bool get isEmotionalLoad {
    return switch (this) {
      MoodFeeling.irritable ||
      MoodFeeling.anxious ||
      MoodFeeling.low ||
      MoodFeeling.sensitive => true,
      MoodFeeling.calm || MoodFeeling.upbeat || MoodFeeling.energised => false,
    };
  }
}

int moodScoreFromCueCount(int selectedCueCount) {
  return selectedCueCount.clamp(0, 5);
}

String moodScoreLabel(int score) {
  return switch (score.clamp(0, 5)) {
    0 => 'Not showing',
    1 => 'Slight',
    2 => 'Mild',
    3 => 'Noticeable',
    4 => 'Strong',
    _ => 'Very strong',
  };
}

String phq9SeverityLabel(int? score) {
  if (score == null) return 'Not added';
  final value = score.clamp(0, 27);
  if (value >= 20) return 'Severe';
  if (value >= 15) return 'Moderately severe';
  if (value >= 10) return 'Moderate';
  if (value >= 5) return 'Mild';
  return 'Minimal';
}

String gad7SeverityLabel(int? score) {
  if (score == null) return 'Not added';
  final value = score.clamp(0, 21);
  if (value >= 15) return 'Severe';
  if (value >= 10) return 'Moderate';
  if (value >= 5) return 'Mild';
  return 'Minimal';
}

class MoodCheckIn {
  const MoodCheckIn({
    required this.id,
    required this.date,
    required this.gelTiming,
    required this.recentDoseChange,
    required this.stress,
    required this.sleepQuality,
    required this.notableEvent,
    required this.feelings,
    required this.notes,
    this.phq9Score,
    this.gad7Score,
  });

  final String id;
  final DateTime date;
  final GelTiming gelTiming;
  final bool recentDoseChange;
  final int stress;
  final int sleepQuality;
  final bool notableEvent;
  final Map<MoodFeeling, int> feelings;
  final String notes;
  final int? phq9Score;
  final int? gad7Score;

  double get emotionalLoad {
    final values = [
      for (final entry in feelings.entries)
        if (entry.key.isEmotionalLoad) entry.value,
    ];
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double get positiveMood {
    final values = [
      for (final entry in feelings.entries)
        if (!entry.key.isEmotionalLoad) entry.value,
    ];
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double get hormoneTimingSignal {
    final doseChangeBoost = recentDoseChange ? 1.0 : 0.0;
    final timing = (gelTiming.proximityScore + doseChangeBoost).clamp(0, 5);
    return emotionalLoad * timing / 5;
  }

  double get contextSignal {
    final poorSleep = 5 - sleepQuality;
    final eventScore = notableEvent ? 4 : 0;
    return (stress + poorSleep + eventScore) / 3;
  }
}
