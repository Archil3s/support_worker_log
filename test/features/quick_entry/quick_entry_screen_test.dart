import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/features/quick_entry/quick_entry_screen.dart';

void main() {
  test('work notes strip PAYE-only attendance and support tags', () {
    final notes = buildQuickEntryVisitNotesForTest(
      selectedNotes: const [
        'Attendance: Client',
        'Tag: 2-up visit',
        'Wellbeing',
        'Agency: WINZ / MSD Blenheim',
      ],
      includePayeContext: false,
      typedNote: 'Followed up by phone.',
    );

    expect(notes, const [
      'Topics covered: Wellbeing',
      'Agency: WINZ / MSD Blenheim',
      'Followed up by phone.',
    ]);
  });

  test('PAYE notes keep attendance and support tags', () {
    final notes = buildQuickEntryVisitNotesForTest(
      selectedNotes: const [
        'Attendance: Support worker',
        'Attendance: Client',
        'Tag: 2-up visit',
        'Wellbeing',
      ],
      includePayeContext: true,
    );

    expect(notes, const [
      'Attendance: Client, Support worker',
      'Tags: 2-up visit',
      'Topics covered: Wellbeing',
    ]);
  });

  test('work active-visit drafts drop hidden PAYE-only raw selections', () {
    final notes = rawQuickEntryVisitNotesForTest(
      selectedNotes: const [
        'Attendance: Client',
        'Tag: Attendance support worker',
        'Transport',
      ],
      includePayeContext: false,
    );

    expect(notes, const ['Transport']);
  });

  test('empty Work support note still keeps the core note format', () {
    final note = buildWorkSupportNoteBreakdownForTest(
      mainTopic: '',
      outcomes: '',
      nextActions: '',
      impression: '',
      referrals: 'No referrals discussed or made this visit.',
      safetyConcerns: 'No safety concerns noted.',
    );

    expect(note, contains('Main topic(s)'));
    expect(note, contains('Outcome(s)'));
    expect(note, contains('Next action(s)'));
    expect(note, contains('Overall impression'));
    expect(note, contains('Referrals'));
    expect(
      note,
      contains('Safety concerns for sexual harm survivors and mental health'),
    );
  });
}
