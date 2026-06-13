import 'package:flutter/material.dart';

import '../models/entry_type.dart';
import '../models/work_entry.dart';

const _rawInvoiceCsv = '''
client,date,type,duration,km,note
BD,20/12/2025,Home Visit,1h,5,Period 14-27 Dec 2025 - Home visit - OK
MS,21/12/2025,Professional Contact,1h,0,Period 14-27 Dec 2025 - Support work - No activity detail - OK
BD,24/12/2025,Home Visit,1h,5,Period 14-27 Dec 2025 - Client name missing from original - REVIEW
BD,14/12/2025,Professional Contact,0.5h,0,Period 14-27 Dec 2025 - Re BD note + CS? - Original date unclear - REVIEW
BD,06/01/2026,Professional Contact,1h,0,Period 28 Dec-10 Jan 2026 - General support - OK
BD,06/01/2026,Professional Contact,1h,0,Period 28 Dec-10 Jan 2026 - Court help - OK
BD,07/01/2026,Professional Contact,2h,0,Period 28 Dec-10 Jan 2026 - Court help - OK
BD,08/01/2026,Home Visit,2h,5,Period 28 Dec-10 Jan 2026 - Home visit / document drop - Client name missing from original - REVIEW
BD,10/01/2026,Home Visit,1h,5,Period 28 Dec-10 Jan 2026 - Home visit - Client name missing from original - REVIEW
PR,05/01/2026,Phone Call,2 min,0,Period 28 Dec-10 Jan 2026 - Phone no pickup x2 - 2 min assumed - REVIEW
PR,09/01/2026,Phone Call,1 min,0,Period 28 Dec-10 Jan 2026 - Phone no pickup - 1 min assumed - REVIEW
PR,10/01/2026,Phone Call,6 min,0,Period 28 Dec-10 Jan 2026 - Phone contact - OK
BD,11/01/2026,Home Visit,1h,5,Period 11-24 Jan 2026 - Home visit - OK
BD,11/01/2026,Text Note,1h,0,Period 11-24 Jan 2026 - Texts - Original date unclear - REVIEW
BD,20/01/2026,Home Visit,2.5h,5,Period 11-24 Jan 2026 - Home visit + call? - REVIEW
MS,12/01/2026,Phone Call,0.5h,0,Period 11-24 Jan 2026 - Phone - OK
MS,14/01/2026,Home Visit,1h,5,Period 11-24 Jan 2026 - Home visit - OK
MS,11/01/2026,Phone Call,0.5h,0,Period 11-24 Jan 2026 - Phone call/advice - Original date unclear - REVIEW
MS,11/01/2026,Phone Call,0.5h,0,Period 11-24 Jan 2026 - Phone advice/court? - Original date unclear - REVIEW
MS,13/01/2026,Home Visit,1h,0,Period 11-24 Jan 2026 - Home visit - Original date corrected to invoice fortnight - REVIEW
PR,20/01/2026,Professional Contact,1h,0,Period 11-24 Jan 2026 - RR / ACC referral - Filed under PR - REVIEW
PR,14/01/2026,Phone Call,9 min,0,Period 11-24 Jan 2026 - Phone 1+8 min - 9 min total - REVIEW
PR,19/01/2026,Phone Call,1 min,0,Period 11-24 Jan 2026 - Phone no pickup - 1 min assumed - REVIEW
PR,20/01/2026,Phone Call,1 min,0,Period 11-24 Jan 2026 - Phone no pickup - 1 min assumed - REVIEW
BD,25/01/2026,Home Visit,2h,5,Period 25 Jan-7 Feb 2026 - Home visit / issue? - REVIEW
BD,25/01/2026,Home Visit,2h,5,Period 25 Jan-7 Feb 2026 - Home + consent - Original date unclear - REVIEW
BD,28/01/2026,Home Visit,1h,5,Period 25 Jan-7 Feb 2026 - Home - OK
BD,25/01/2026,Home Visit,1h,5,Period 25 Jan-7 Feb 2026 - Home - Original date unclear - REVIEW
PR,28/01/2026,Phone Call,0.5h,0,Period 25 Jan-7 Feb 2026 - Date unclear 28 or 30 Jan - Phone call - REVIEW
PR,25/01/2026,Home Visit,1h,5,Period 25 Jan-7 Feb 2026 - Home - Original date unclear - REVIEW
GM,25/01/2026,Phone Call,0.5h,0,Period 25 Jan-7 Feb 2026 - Call - OK
GM,25/01/2026,Professional Contact,1h,0,Period 25 Jan-7 Feb 2026 - Lunch? - Original date unclear - REVIEW
PR,25/01/2026,Phone Call,3 min,0,Period 25 Jan-7 Feb 2026 - Phone no pickup x3 - 3 min assumed - REVIEW
PR,28/01/2026,Phone Call,5 min,0,Period 25 Jan-7 Feb 2026 - Phone contact - 5 min 4+1 - OK
PR,02/02/2026,Phone Call,1 min,0,Period 25 Jan-7 Feb 2026 - Phone no pickup - 1 min assumed - REVIEW
PR,03/02/2026,Phone Call,1 min,0,Period 25 Jan-7 Feb 2026 - Phone no pickup - 1 min assumed - REVIEW
PR,04/02/2026,Phone Call,1 min,0,Period 25 Jan-7 Feb 2026 - Phone contact - OK
PR,05/02/2026,Phone Call,1 min,0,Period 25 Jan-7 Feb 2026 - Phone contact - OK
MS,12/02/2026,Phone Call,1h,0,Period 8-21 Feb 2026 - Phone / case referral - Ref 1300087-93M - REVIEW
PR,17/02/2026,Professional Contact,1h,0,Period 8-21 Feb 2026 - PR/Powe - Ref 130332-45 - REVIEW
BD,08/02/2026,Professional Contact,1h,0,Period 8-21 Feb 2026 - Ref 130436-58 - Original date unclear - REVIEW
BD,08/02/2026,Professional Contact,1h,0,Period 8-21 Feb 2026 - Ref 130448 - Original date unclear - REVIEW
PR,16/02/2026,Phone Call,2 min,0,Period 8-21 Feb 2026 - Phone contact - OK
PR,08/03/2026,Phone Call,1 min,0,Period 8-21 Mar 2026 - Phone no pickup - 1 min assumed - REVIEW
PR,22/03/2026,Phone Call,1 min,0,Period 22 Mar-4 Apr 2026 - Phone no pickup - 1 min assumed - REVIEW
PR,08/04/2026,Phone Call,2 min,0,Period 5-18 Apr 2026 - Phone contact - OK
PR,13/04/2026,Phone Call,1 min,0,Period 5-18 Apr 2026 - Phone contact - OK
PR,13/04/2026,Phone Call,1 min,0,Period 5-18 Apr 2026 - Phone no pickup - 1 min assumed - REVIEW
PR,29/04/2026,Phone Call,26 min,0,Period 19 Apr-2 May 2026 - Phone call answered - OK
''';

List<WorkEntry> sampleInvoiceEntries() {
  final lines = _rawInvoiceCsv
      .trim()
      .split(RegExp(r'\r?\n'))
      .skip(1)
      .where((line) => line.trim().isNotEmpty)
      .toList();

  final entries = <WorkEntry>[];

  for (var index = 0; index < lines.length; index++) {
    final parts = lines[index].split(',');

    if (parts.length < 6) continue;

    final client = parts[0].trim();
    final date = _parseDate(parts[1].trim());
    final type = _parseType(parts[2].trim());
    final minutes = _parseDuration(parts[3].trim());
    final kilometres = double.tryParse(parts[4].trim()) ?? 0;
    final note = parts.sublist(5).join(',').trim();

    final hasOdo = type == EntryType.homeVisit && kilometres > 0;

    entries.add(
      WorkEntry(
        id: 'inv-${(index + 1).toString().padLeft(3, '0')}',
        client: client,
        type: type,
        date: date,
        startTime: const TimeOfDay(hour: 9, minute: 0),
        minutes: minutes,
        notes: [note],
        odometerStart: hasOdo ? 0 : null,
        odometerEnd: hasOdo ? kilometres : null,
      ),
    );
  }

  return entries;
}

DateTime _parseDate(String value) {
  final parts = value.split('/');
  final day = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  final year = int.parse(parts[2]);

  return DateTime(year, month, day);
}

EntryType _parseType(String value) {
  final lower = value.toLowerCase();

  if (lower.contains('phone')) return EntryType.phoneCall;
  if (lower.contains('video')) return EntryType.videoCall;
  if (lower.contains('email') && lower.contains('professional')) {
    return EntryType.emailProfessional;
  }
  if (lower.contains('email')) return EntryType.emailClient;
  if (lower.contains('education') || lower.contains('resource')) {
    return EntryType.adminEducationResources;
  }
  if (lower.contains('admin')) return EntryType.adminEducationResources;
  if (lower.contains('text')) return EntryType.textNote;
  if (lower.contains('home')) return EntryType.homeVisit;

  return EntryType.professionalContact;
}

int _parseDuration(String value) {
  final lower = value.toLowerCase().trim();

  if (lower.contains('min')) {
    final number = RegExp(r'\d+(?:\.\d+)?').firstMatch(lower)?.group(0);
    return (double.tryParse(number ?? '0') ?? 0).round().clamp(1, 1440);
  }

  if (lower.contains('h')) {
    final number = RegExp(r'\d+(?:\.\d+)?').firstMatch(lower)?.group(0);
    final hours = double.tryParse(number ?? '0') ?? 0;
    return (hours * 60).round().clamp(1, 1440);
  }

  final plain = double.tryParse(lower) ?? 0;
  if (plain <= 24) return (plain * 60).round().clamp(1, 1440);

  return plain.round().clamp(1, 1440);
}
