import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/features/mood/data/models/mood_check_in_model.dart';
import 'package:support_worker_log/features/mood/domain/entities/mood_check_in.dart';

void main() {
  test('emotion cue counts become bounded scores and plain labels', () {
    expect(moodScoreFromCueCount(0), 0);
    expect(moodScoreFromCueCount(3), 3);
    expect(moodScoreFromCueCount(8), 5);
    expect(moodScoreLabel(0), 'Not showing');
    expect(moodScoreLabel(3), 'Noticeable');
    expect(moodScoreLabel(5), 'Very strong');
  });

  test('validated measure labels follow PHQ-9 and GAD-7 severity bands', () {
    expect(phq9SeverityLabel(null), 'Not added');
    expect(phq9SeverityLabel(4), 'Minimal');
    expect(phq9SeverityLabel(5), 'Mild');
    expect(phq9SeverityLabel(10), 'Moderate');
    expect(phq9SeverityLabel(15), 'Moderately severe');
    expect(phq9SeverityLabel(20), 'Severe');
    expect(gad7SeverityLabel(null), 'Not added');
    expect(gad7SeverityLabel(4), 'Minimal');
    expect(gad7SeverityLabel(5), 'Mild');
    expect(gad7SeverityLabel(10), 'Moderate');
    expect(gad7SeverityLabel(15), 'Severe');
  });

  test('mood check-in round trips through personal log storage', () {
    final checkIn = MoodCheckIn(
      id: 'mood-1',
      date: DateTime(2026, 6, 13, 9, 30),
      gelTiming: GelTiming.after0To4,
      recentDoseChange: true,
      stress: 4,
      sleepQuality: 2,
      notableEvent: true,
      feelings: {
        for (final feeling in MoodFeeling.values) feeling: feeling.index % 6,
      },
      notes: 'Felt more reactive after a difficult morning.',
      phq9Score: 12,
      gad7Score: 9,
    );

    final entry = MoodCheckInModel(checkIn).toPersonalLogEntry();
    final restored = MoodCheckInModel.fromPersonalLogEntry(entry);

    expect(entry.title, startsWith('Mood Tracker: '));
    expect(restored, isNotNull);
    expect(restored!.id, checkIn.id);
    expect(restored.gelTiming, GelTiming.after0To4);
    expect(restored.recentDoseChange, isTrue);
    expect(restored.stress, 4);
    expect(restored.sleepQuality, 2);
    expect(restored.notableEvent, isTrue);
    expect(restored.feelings, checkIn.feelings);
    expect(restored.notes, checkIn.notes);
    expect(restored.phq9Score, 12);
    expect(restored.gad7Score, 9);
  });

  test('legacy mood and testosterone entries still restore', () {
    final checkIn = MoodCheckIn(
      id: 'mood-legacy',
      date: DateTime(2026, 6, 14),
      gelTiming: GelTiming.after4To8,
      recentDoseChange: false,
      stress: 2,
      sleepQuality: 4,
      notableEvent: false,
      feelings: {
        for (final feeling in MoodFeeling.values) feeling: feeling.index,
      },
      notes: '',
    );

    final entry = MoodCheckInModel(checkIn).toPersonalLogEntry();
    final legacyEntry = entry.copyWith(title: 'Mood & Testosterone: Low 2/5');

    expect(MoodCheckInModel.fromPersonalLogEntry(legacyEntry), isNotNull);
    expect(MoodCheckInModel.isMoodEntry(legacyEntry), isTrue);
  });

  test('context and hormone timing signals remain on a zero to five scale', () {
    final checkIn = MoodCheckIn(
      id: 'mood-2',
      date: DateTime(2026, 6, 13),
      gelTiming: GelTiming.after0To4,
      recentDoseChange: true,
      stress: 5,
      sleepQuality: 0,
      notableEvent: true,
      feelings: {
        for (final feeling in MoodFeeling.values)
          feeling: feeling.isEmotionalLoad ? 5 : 0,
      },
      notes: '',
    );

    expect(checkIn.emotionalLoad, 5);
    expect(checkIn.hormoneTimingSignal, inInclusiveRange(0, 5));
    expect(checkIn.contextSignal, inInclusiveRange(0, 5));
  });
}
