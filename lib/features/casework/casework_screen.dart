import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/widgets/section_card.dart';

const _caseworkInk = Color(0xFFE7ECFA);
const _caseworkInkSoft = Color(0xFF20283B);
const _caseworkBlue = Color(0xFF4F8DF7);
const _caseworkAccent = Color(0xFF4F8DF7);
const _caseworkSurface = Color(0xFF151B29);
const _caseworkCanvas = Color(0xFF090E17);
const _caseworkLine = Color(0xFF34405F);
const _caseworkMuted = Color(0xFF8396C7);
const _caseworkPanel = Color(0xFF101827);
const _caseworkSelected = Color(0xFF13294D);
const _caseworkUpdated = Color(0xFFFFB84D);
const _caseworkCompleted = Color(0xFF31D17C);

enum _CaseworkFocus {
  walkIn,
  situation,
  safety,
  documents,
  msd,
  housing,
  accommodation,
  probation,
  referrals,
  file,
}

class CaseworkScreen extends StatefulWidget {
  const CaseworkScreen({super.key});

  @override
  State<CaseworkScreen> createState() => _CaseworkScreenState();
}

class _CaseworkScreenState extends State<CaseworkScreen> {
  static const _legacyDraftKey = 'casework_advocacy_draft_v1';
  static const _profilesKey = 'casework_code_profiles_v1';

  final clientInitialsController = TextEditingController();
  final workerInitialsController = TextEditingController();
  final deadlineController = TextEditingController(text: 'Today');
  final additionalContextController = TextEditingController();

  _CaseworkFocus focus = _CaseworkFocus.walkIn;
  String urgency = 'high';
  String contact = 'Walk-in';
  String consent = 'Verbal consent given';
  String noteType = 'Peer support housing note';
  String socialHousingRating = 'Not checked';
  String probationStatus = 'Not applicable';

  final presentingNeeds = <String>{};
  final situationUnderstanding = <String>{};
  final immediateSafety = <String>{};
  final documents = <String>{};
  final msdCriteria = <String>{};
  final msdAdvocacy = <String>{};
  final socialHousing = <String>{};
  final housingApplications = <String>{};
  final accommodationOptions = <String>{};
  final probationActions = <String>{};
  final referrals = <String>{};
  final supportNeeds = <String>{};
  final referralFilters = <String>{};
  final roadblocks = <String>{};
  final updatedFocuses = <_CaseworkFocus>{};
  final completedFocuses = <_CaseworkFocus>{};
  final actionLog = <_ActionLogEntry>[];
  final requestHistory = <_RequestHistoryEntry>[];
  final profiles = <String, _CaseProfileRecord>{};

  String activeProfileCode = 'CASE-001';

  List<String> get _sortedProfileCodes {
    final codes = profiles.keys.toList()..sort();
    if (codes.isEmpty) return [activeProfileCode];
    return codes;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadDraft());
  }

  @override
  void dispose() {
    clientInitialsController.dispose();
    workerInitialsController.dispose();
    deadlineController.dispose();
    additionalContextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1050;
        final noteFile = _buildNoteFile();

        if (desktop) {
          return _desktopCaseworkShell(
            height: constraints.maxHeight,
            noteFile: noteFile,
          );
        }

        return _compactCaseworkShell(noteFile);
      },
    );
  }

  Widget _desktopCaseworkShell({
    required double height,
    required String noteFile,
  }) {
    return SizedBox(
      height: height.isFinite ? height : null,
      child: Column(
        children: [
          _DesktopTopBar(
            onSave: _saveSnapshot,
            onNew: _showCreateProfileDialog,
            onOutput: () => setState(() => focus = _CaseworkFocus.file),
            onClear: _confirmClearDraft,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DesktopWorkflowRail(
                  current: focus,
                  updatedFocuses: updatedFocuses,
                  completedFocuses: completedFocuses,
                  onChanged: (value) {
                    setState(() => focus = value);
                    unawaited(_saveDraft());
                  },
                  onUpdatedToggle: _toggleUpdated,
                  onCompletedToggle: _toggleCompleted,
                ),
                _DesktopClientRail(
                  clientInitialsController: clientInitialsController,
                  workerInitialsController: workerInitialsController,
                  deadlineController: deadlineController,
                  contact: contact,
                  consent: consent,
                  urgency: urgency,
                  noteType: noteType,
                  actionCount: actionLog.length,
                  profileCodes: _sortedProfileCodes,
                  activeProfileCode: activeProfileCode,
                  onProfileChanged: (value) => unawaited(_switchProfile(value)),
                  onCreateProfile: _showCreateProfileDialog,
                  onDeleteProfile: _confirmDeleteProfile,
                  onContactChanged: (value) {
                    setState(() => contact = value);
                    unawaited(_saveDraft());
                  },
                  onConsentChanged: (value) {
                    setState(() => consent = value);
                    unawaited(_saveDraft());
                  },
                  onUrgencyChanged: (value) {
                    setState(() => urgency = value);
                    unawaited(_saveDraft());
                  },
                  onNoteTypeChanged: (value) {
                    setState(() => noteType = value);
                    unawaited(_saveDraft());
                  },
                  onTextChanged: (_) {
                    setState(() {});
                    unawaited(_saveDraft());
                  },
                  onClearNote: () {
                    setState(() {
                      presentingNeeds.clear();
                      situationUnderstanding.clear();
                      immediateSafety.clear();
                      documents.clear();
                      msdCriteria.clear();
                      msdAdvocacy.clear();
                      socialHousing.clear();
                      housingApplications.clear();
                      accommodationOptions.clear();
                      probationActions.clear();
                      referrals.clear();
                      supportNeeds.clear();
                      referralFilters.clear();
                      roadblocks.clear();
                      actionLog.clear();
                      additionalContextController.clear();
                    });
                    unawaited(_saveDraft());
                  },
                ),
                Expanded(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_caseworkCanvas, _caseworkSurface],
                      ),
                    ),
                    child: SingleChildScrollView(
                      key: ValueKey(focus),
                      primary: false,
                      padding: const EdgeInsets.fromLTRB(22, 28, 22, 110),
                      child: _desktopFocusedSection(),
                    ),
                  ),
                ),
                _DesktopNoteOutput(
                  noteType: noteType,
                  noteFile: noteFile,
                  onNoteTypeChanged: (value) {
                    setState(() => noteType = value);
                    unawaited(_saveDraft());
                  },
                  onCopy: () => _copyNote(noteFile),
                  onClear: () {
                    setState(() => actionLog.clear());
                    unawaited(_saveDraft());
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactCaseworkShell(String noteFile) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_caseworkCanvas, _caseworkSurface],
        ),
      ),
      child: ListView(
        key: const ValueKey('casework-compact-list'),
        primary: false,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
        children: [
          _CompactCaseworkHeader(
            onSave: _saveSnapshot,
            onNew: _showCreateProfileDialog,
            onOutput: () => setState(() => focus = _CaseworkFocus.file),
            onClear: _confirmClearDraft,
          ),
          const SizedBox(height: 12),
          _DesktopCard(
            title: 'Fast pathways',
            icon: Icons.bolt_outlined,
            child: _WordingGrid(
              actions: _urgencyActions,
              onSelected: _applyUrgencyAction,
            ),
          ),
          const SizedBox(height: 12),
          _CompactClientCard(
            clientInitialsController: clientInitialsController,
            workerInitialsController: workerInitialsController,
            deadlineController: deadlineController,
            contact: contact,
            consent: consent,
            urgency: urgency,
            noteType: noteType,
            profileCodes: _sortedProfileCodes,
            activeProfileCode: activeProfileCode,
            onProfileChanged: (value) => unawaited(_switchProfile(value)),
            onCreateProfile: _showCreateProfileDialog,
            onContactChanged: (value) {
              setState(() => contact = value);
              unawaited(_saveDraft());
            },
            onConsentChanged: (value) {
              setState(() => consent = value);
              unawaited(_saveDraft());
            },
            onUrgencyChanged: (value) {
              setState(() => urgency = value);
              unawaited(_saveDraft());
            },
            onNoteTypeChanged: (value) {
              setState(() => noteType = value);
              unawaited(_saveDraft());
            },
            onTextChanged: (_) {
              setState(() {});
              unawaited(_saveDraft());
            },
          ),
          const SizedBox(height: 12),
          _CompactLiveCard(
            urgency: urgency,
            openStepCount: _openNextSteps().length,
            actionCount: actionLog.length,
            latestAction: actionLog.isEmpty ? null : actionLog.first,
            requestHistory: requestHistory,
            onQuickLog: _applyQuickLog,
            onClear: _confirmClearDraft,
          ),
          const SizedBox(height: 12),
          _CompactFocusBar(
            current: focus,
            updatedFocuses: updatedFocuses,
            completedFocuses: completedFocuses,
            onChanged: (value) {
              setState(() => focus = value);
              unawaited(_saveDraft());
            },
            onUpdatedToggle: (value) => _toggleUpdated([value]),
            onCompletedToggle: (value) => _toggleCompleted([value]),
          ),
          const SizedBox(height: 12),
          _desktopFocusedSection(),
          const SizedBox(height: 12),
          _CompactNoteOutput(
            noteType: noteType,
            noteFile: noteFile,
            onNoteTypeChanged: (value) {
              setState(() => noteType = value);
              unawaited(_saveDraft());
            },
            onCopy: () => _copyNote(noteFile),
          ),
        ],
      ),
    );
  }

  Widget _desktopFocusedSection() {
    switch (focus) {
      case _CaseworkFocus.walkIn:
      case _CaseworkFocus.situation:
        return _desktopCaseFlowSection();
      case _CaseworkFocus.safety:
        return _desktopSocialSupportSection();
      case _CaseworkFocus.documents:
        return _desktopEvidenceSection();
      case _CaseworkFocus.msd:
        return _desktopMsdSection();
      case _CaseworkFocus.housing:
      case _CaseworkFocus.accommodation:
        return _desktopCmmSection();
      case _CaseworkFocus.probation:
        return _desktopDiarySection();
      case _CaseworkFocus.referrals:
        return _desktopReferralDirectory();
      case _CaseworkFocus.file:
        return _focusedSection(_buildNoteFile());
    }
  }

  Widget _desktopCaseFlowSection() {
    return _DesktopPage(
      title: 'Case Flow',
      subtitle:
          'Select presenting issues and housing status to build the case context.',
      child: Column(
        children: [
          _LivingPathwayFlow(
            profileCode: activeProfileCode,
            history: requestHistory,
            openStepCount: _openNextSteps().length,
          ),
          const SizedBox(height: 16),
          _DesktopStepBar(current: 0),
          const SizedBox(height: 16),
          _ResponsiveColumns(
            children: [
              _DesktopCard(
                title: 'Main Issue/s',
                icon: Icons.crisis_alert_outlined,
                child: _ChipPicker(
                  options: _presentingNeedOptions,
                  selected: presentingNeeds,
                  onChanged: (item, selected) => _toggleLogged(
                    presentingNeeds,
                    item,
                    selected,
                    'Presenting need',
                  ),
                ),
              ),
              _DesktopCard(
                title: 'Housing Status',
                icon: Icons.home_work_outlined,
                child: _ChipPicker(
                  options: _housingStatusOptions,
                  selected: situationUnderstanding,
                  onChanged: (item, selected) => _toggleLogged(
                    situationUnderstanding,
                    item,
                    selected,
                    'Housing status',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DesktopCard(
            title: 'Evidence & Barriers',
            icon: Icons.fact_check_outlined,
            child: _ChipPicker(
              options: _evidenceBarrierOptions,
              selected: documents,
              onChanged: (item, selected) =>
                  _toggleLogged(documents, item, selected, 'Evidence'),
            ),
          ),
          const SizedBox(height: 16),
          _DesktopCard(
            title: 'Main Notes (optional)',
            icon: Icons.notes_outlined,
            child: TextField(
              controller: additionalContextController,
              maxLines: 4,
              onChanged: (value) {
                setState(() {});
                unawaited(_saveDraft());
              },
              decoration: const InputDecoration(
                hintText:
                    'Add only the detail the quick selections did not capture...',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopMsdSection() {
    return _DesktopPage(
      title: 'Housing + MSD',
      subtitle:
          'Work and Income / MSD housing pathways and assessment support.',
      child: Column(
        children: [
          const _WarningStrip(
            text:
                'Always verify eligibility, re-grant rules, contribution amounts and supplier details directly with MSD. This tool does not guarantee approval.',
          ),
          const SizedBox(height: 14),
          _ResponsiveColumns(
            children: [
              _DesktopCard(
                title: 'Emergency Housing',
                icon: Icons.apartment_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ChipPicker(
                      options: _emergencyHousingOptions,
                      selected: msdAdvocacy,
                      onChanged: (item, selected) =>
                          _toggleLogged(msdAdvocacy, item, selected, 'MSD/EH'),
                    ),
                    const SizedBox(height: 14),
                    const _InfoBlock(
                      title: 'Re-grant pathway',
                      text:
                          'Client must attend the follow-up/re-grant appointment, show agreed actions, housing search activity, and address EH contribution issues early.',
                    ),
                    const SizedBox(height: 10),
                    const _InfoBlock(
                      title: 'Contribution rules',
                      text:
                          'After 7 nights MSD can require an Emergency Housing Contribution. Missed payments can create warnings or non-entitlement risk.',
                    ),
                  ],
                ),
              ),
              _DesktopCard(
                title: 'Public Housing Register',
                icon: Icons.domain_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ChipPicker(
                      options: _publicHousingOptions,
                      selected: socialHousing,
                      onChanged: (item, selected) => _toggleLogged(
                        socialHousing,
                        item,
                        selected,
                        'Public housing',
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _InfoBlock(
                      title: 'Priority pathway',
                      text:
                          'Priority A/B is assessed by MSD. Worker can support by providing evidence of current housing situation, safety concerns, health/disability needs, family violence history, children in household, Corrections/bail requirements.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ResponsiveColumns(
            children: [
              _DesktopCard(
                title: 'Financial Support',
                icon: Icons.savings_outlined,
                child: _ChipPicker(
                  options: _financialSupportOptions,
                  selected: msdAdvocacy,
                  onChanged: (item, selected) => _toggleLogged(
                    msdAdvocacy,
                    item,
                    selected,
                    'Financial support',
                  ),
                ),
              ),
              _DesktopCard(
                title: 'Evidence Pack',
                icon: Icons.description_outlined,
                child: _ChecklistLink(
                  selectedCount: documents.length,
                  onPressed: () {
                    setState(() => focus = _CaseworkFocus.documents);
                    unawaited(_saveDraft());
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _desktopEvidenceSection() {
    return _DesktopPage(
      title: 'Before MSD Can Grant Emergency Housing',
      subtitle:
          'Tick what has been checked or documented before the MSD call/re-grant. These are practical worker prompts, not approval rules.',
      child: Column(
        children: [
          const _WarningStrip(
            text:
                'Use this as a worker checklist. Requirements vary by MSD, Corrections, Court/MOJ, agency criteria and client situation.',
          ),
          const SizedBox(height: 14),
          _ReadinessGrid(
            items: _ehReadinessItems,
            selected: msdCriteria,
            onChanged: (item, selected) => _toggleLogged(
              msdCriteria,
              item.title,
              selected,
              'EH readiness',
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopCmmSection() {
    return _DesktopPage(
      title: 'CMM Housing - Blenheim / Te Tau Ihu',
      subtitle:
          'Pathways for emergency housing navigation, transitional housing, sustaining tenancies, Housing First, rapid rehousing and social housing.',
      child: Column(
        children: [
          const _ResponsiveColumns(
            children: [
              _PathwayStep(
                number: '1',
                title: 'Tonight safety',
                text:
                    'Confirm no safe place tonight, transport, ID, income and children.',
              ),
              _PathwayStep(
                number: '2',
                title: 'MSD assessment',
                text:
                    'Work and Income checks emergency housing and transitional availability.',
              ),
              _PathwayStep(
                number: '3',
                title: 'CMM navigation',
                text:
                    'CMM supports MSD clients and housing advocacy/navigation pathways.',
              ),
              _PathwayStep(
                number: '4',
                title: 'Exit plan',
                text:
                    'Build diary evidence, referrals, housing search and long-term pathway.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ResponsiveColumns(
            children: [
              _DesktopCard(
                title: 'CMM Pathway Selector',
                icon: Icons.route_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ChipPicker(
                      options: _cmmPathwayOptions,
                      selected: msdAdvocacy,
                      onChanged: (item, selected) =>
                          _toggleLogged(msdAdvocacy, item, selected, 'CMM'),
                    ),
                    const SizedBox(height: 14),
                    const _InfoBlock(
                      title: 'Best-fit quick guide',
                      text:
                          'Emergency accommodation: immediate MSD client support. Transitional housing: medium-term housing and social support. Housing First: chronic homelessness and multiple complex needs. Sustaining Tenancies: prevent tenancy loss.',
                    ),
                  ],
                ),
              ),
              _DesktopCard(
                title: 'CMM / MSD Readiness',
                icon: Icons.fact_check_outlined,
                child: _ChecklistLink(
                  selectedCount: documents.length,
                  onPressed: () {
                    setState(() => focus = _CaseworkFocus.documents);
                    unawaited(_saveDraft());
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ResponsiveColumns(
            children: [
              _DesktopCard(
                title: 'Quick MSD / CMM Wording',
                icon: Icons.quickreply_outlined,
                child: _WordingGrid(
                  actions: _wordingActions,
                  onSelected: _applyUrgencyAction,
                ),
              ),
              _DesktopCard(
                title: 'Quick Diary Actions',
                icon: Icons.flash_on_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ActionButtonWrap(
                      actions: _quickLogActions,
                      onSelected: _applyQuickLog,
                    ),
                    const SizedBox(height: 14),
                    const _InfoBlock(
                      title: 'Core CMM contacts / pathways',
                      text:
                          'Te Tau Ihu CMM Blenheim: 69 Scott St, Blenheim 7201. Housing Advocacy & Navigation / Community Outreach: 0800 432 536. Referral email: referralscmmblenheim@mmsi.org.nz.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _desktopReferralDirectory() {
    final filtersSelected = referralFilters.isNotEmpty;
    final filtered = filtersSelected
        ? _filteredReferrals()
        : const <_Referral>[];

    return _DesktopPage(
      title: 'Programmes + Referrals',
      subtitle:
          'Choose local pathways and services; selected items flow into the live note.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DesktopCard(
            title: 'Quick filters',
            icon: Icons.filter_alt_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need / situation',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                _ChipPicker(
                  options: _socialSupportOptions,
                  selected: referralFilters,
                  onChanged: (item, selected) => _toggleLogged(
                    referralFilters,
                    item,
                    selected,
                    'Referral filter',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pathway',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                _ChipPicker(
                  options: _referralFilterOptions,
                  selected: referralFilters,
                  onChanged: (item, selected) => _toggleLogged(
                    referralFilters,
                    item,
                    selected,
                    'Referral filter',
                  ),
                ),
                if (filtersSelected) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        '${filtered.length} services shown',
                        style: const TextStyle(
                          color: _caseworkMuted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            referralFilters.clear();
                          });
                          unawaited(_saveDraft());
                        },
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Reset filters'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DesktopCard(
            title: 'Services / Agencies',
            icon: Icons.business_outlined,
            child: !filtersSelected
                ? const Text(
                    'Choose a need or quick filter to show matching services.',
                    style: TextStyle(color: _caseworkMuted),
                  )
                : filtered.isEmpty
                ? const Text(
                    'No services match these filters.',
                    style: TextStyle(color: _caseworkMuted),
                  )
                : Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      for (final referral in filtered)
                        SizedBox(
                          width: 300,
                          child: _ReferralCard(
                            referral: referral,
                            selected: _isReferralSelected(referral),
                            selectedProgrammes: _selectedReferralProgrammes(
                              referral,
                            ),
                            onToggle: () => _toggleReferralAgency(referral),
                            onProgrammeToggle: (programme, selected) =>
                                _toggleReferralProgramme(
                                  referral,
                                  programme,
                                  selected,
                                ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _desktopSocialSupportSection() {
    return _DesktopPage(
      title: 'Social Support',
      subtitle:
          'Common support needs and local referral categories for Blenheim / Marlborough.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DesktopCard(
            title: 'Needs / situation',
            icon: Icons.volunteer_activism_outlined,
            child: _ChipPicker(
              options: _socialSupportOptions,
              selected: supportNeeds,
              onChanged: (item, selected) =>
                  _toggleLogged(supportNeeds, item, selected, 'Social support'),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () {
                setState(() {
                  referralFilters.addAll(supportNeeds);
                  focus = _CaseworkFocus.referrals;
                });
                unawaited(_saveDraft());
              },
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Find matching services'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopDiarySection() {
    return _DesktopPage(
      title: 'Diary + Objections',
      subtitle:
          'Record meaningful actions, contact attempts, responses and objections.',
      child: Column(
        children: [
          _DesktopCard(
            title: 'Quick diary actions',
            icon: Icons.edit_note_outlined,
            child: _ActionButtonWrap(
              actions: _diaryQuickActions,
              onSelected: _applyQuickLog,
            ),
          ),
          const SizedBox(height: 16),
          _ResponsiveColumns(
            children: [
              _DesktopCard(
                title: 'Diary Log',
                icon: Icons.list_alt_outlined,
                child: actionLog.isEmpty
                    ? const Text('No entries yet.')
                    : Column(
                        children: [
                          for (final entry in actionLog)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.event_note_outlined),
                              title: Text(entry.action),
                              subtitle: Text(
                                '${_dateTime(entry.time)} | ${entry.category}',
                              ),
                            ),
                        ],
                      ),
              ),
              _DesktopCard(
                title: 'Common Objections',
                icon: Icons.record_voice_over_outlined,
                child: _ChipPicker(
                  options: _commonObjections,
                  selected: roadblocks,
                  onChanged: (item, selected) =>
                      _toggleLogged(roadblocks, item, selected, 'Objection'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _focusedSection(String noteFile) {
    switch (focus) {
      case _CaseworkFocus.walkIn:
        return _walkInSection();
      case _CaseworkFocus.situation:
        return _situationSection();
      case _CaseworkFocus.safety:
        return _safetySection();
      case _CaseworkFocus.documents:
        return _documentsSection();
      case _CaseworkFocus.msd:
        return _msdSection();
      case _CaseworkFocus.housing:
        return _housingSection();
      case _CaseworkFocus.accommodation:
        return _accommodationSection();
      case _CaseworkFocus.probation:
        return _probationSection();
      case _CaseworkFocus.referrals:
        return _referralsSection();
      case _CaseworkFocus.file:
        return _fileSection(noteFile);
    }
  }

  Widget _walkInSection() {
    return Column(
      children: [
        SectionCard(
          title: 'Walk-In Advocacy Intake',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _PrivacyPanel(),
              const SizedBox(height: 12),
              _FieldGrid(
                children: [
                  _TextInput(
                    controller: clientInitialsController,
                    label: 'Client code',
                    hint: 'CASE-001',
                    readOnly: true,
                    onChanged: (_) {},
                  ),
                  _TextInput(
                    controller: workerInitialsController,
                    label: 'Worker initials',
                    hint: 'DW',
                    onChanged: (_) {
                      setState(() {});
                      unawaited(_saveDraft());
                    },
                  ),
                  _DropdownInput(
                    label: 'Contact',
                    value: contact,
                    values: _contacts,
                    onChanged: (value) {
                      setState(() => contact = value);
                      unawaited(_saveDraft());
                      _log('Contact type set: $value', 'Intake');
                    },
                  ),
                  _DropdownInput(
                    label: 'Consent',
                    value: consent,
                    values: _consents,
                    onChanged: (value) {
                      setState(() => consent = value);
                      unawaited(_saveDraft());
                      _log('Consent status set: $value', 'Privacy');
                    },
                  ),
                  _DropdownInput(
                    label: 'Social housing rating',
                    value: socialHousingRating,
                    values: _socialHousingRatings,
                    onChanged: (value) {
                      setState(() => socialHousingRating = value);
                      unawaited(_saveDraft());
                      _log('Social housing rating set: $value', 'Rating');
                    },
                  ),
                  _DropdownInput(
                    label: 'Probation / bail',
                    value: probationStatus,
                    values: _probationStatuses,
                    onChanged: (value) {
                      setState(() => probationStatus = value);
                      unawaited(_saveDraft());
                      _log('Probation/bail status set: $value', 'Probation');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _UrgencyPicker(
                value: urgency,
                onChanged: (value) {
                  setState(() => urgency = value);
                  unawaited(_saveDraft());
                  _log('Urgency set: ${value.toUpperCase()}', 'Triage');
                },
              ),
              const SizedBox(height: 12),
              _TextInput(
                controller: deadlineController,
                label: 'Next deadline',
                hint: 'Today, tonight, before 4pm, EH expires Friday',
                onChanged: (_) {
                  setState(() {});
                  unawaited(_saveDraft());
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Presenting Need',
          child: _ChecklistGroup(
            options: _presentingNeedOptions,
            selected: presentingNeeds,
            onChanged: (item, selected) => _toggleLogged(
              presentingNeeds,
              item,
              selected,
              'Presenting need',
            ),
          ),
        ),
      ],
    );
  }

  Widget _situationSection() {
    return SectionCard(
      title: 'Identify Scope',
      child: Column(
        children: [
          for (final group in _situationScopeGroups)
            _ScopeGroupCard(
              group: group,
              selected: situationUnderstanding,
              onChanged: (item, selected) => _toggleLogged(
                situationUnderstanding,
                item,
                selected,
                'Scope',
              ),
            ),
        ],
      ),
    );
  }

  Widget _safetySection() {
    return Column(
      children: [
        SectionCard(
          title: 'Immediate Safety Before Agencies',
          child: _ChecklistGroup(
            options: _immediateSafetyOptions,
            selected: immediateSafety,
            onChanged: (item, selected) => _toggleLogged(
              immediateSafety,
              item,
              selected,
              'Immediate safety',
            ),
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Roadblock Prevention',
          child: _ChecklistGroup(
            options: _roadblockOptions,
            selected: roadblocks,
            onChanged: (item, selected) =>
                _toggleLogged(roadblocks, item, selected, 'Roadblock check'),
          ),
        ),
      ],
    );
  }

  Widget _documentsSection() {
    return SectionCard(
      title: 'Documents And Proof Ready',
      child: _ChecklistGroup(
        options: _documentOptions,
        selected: documents,
        onChanged: (item, selected) =>
            _toggleLogged(documents, item, selected, 'Documents'),
      ),
    );
  }

  Widget _msdSection() {
    return Column(
      children: [
        SectionCard(
          title: 'MSD Emergency Housing Criteria',
          child: _ChecklistGroup(
            options: _msdCriteriaOptions,
            selected: msdCriteria,
            onChanged: (item, selected) =>
                _toggleLogged(msdCriteria, item, selected, 'MSD criteria'),
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'MSD / CMM Advocacy',
          child: _ChecklistGroup(
            options: _msdAdvocacyOptions,
            selected: msdAdvocacy,
            onChanged: (item, selected) =>
                _toggleLogged(msdAdvocacy, item, selected, 'MSD/CMM'),
          ),
        ),
      ],
    );
  }

  Widget _housingSection() {
    return Column(
      children: [
        SectionCard(
          title: 'Social Housing Rating',
          child: _ChecklistGroup(
            options: _socialHousingOptions,
            selected: socialHousing,
            onChanged: (item, selected) =>
                _toggleLogged(socialHousing, item, selected, 'Social housing'),
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Housing Applications',
          child: _ChecklistGroup(
            options: _housingApplicationOptions,
            selected: housingApplications,
            onChanged: (item, selected) => _toggleLogged(
              housingApplications,
              item,
              selected,
              'Housing application',
            ),
          ),
        ),
      ],
    );
  }

  Widget _accommodationSection() {
    return SectionCard(
      title: 'Accommodation Options',
      child: _ChecklistGroup(
        options: _accommodationOptions,
        selected: accommodationOptions,
        onChanged: (item, selected) => _toggleLogged(
          accommodationOptions,
          item,
          selected,
          'Accommodation',
        ),
      ),
    );
  }

  Widget _probationSection() {
    return SectionCard(
      title: 'Probation / Bail Address',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DropdownInput(
            label: 'Probation / bail status',
            value: probationStatus,
            values: _probationStatuses,
            onChanged: (value) {
              setState(() => probationStatus = value);
              unawaited(_saveDraft());
              _log('Probation/bail status set: $value', 'Probation');
            },
          ),
          const SizedBox(height: 12),
          _ChecklistGroup(
            options: _probationActionOptions,
            selected: probationActions,
            onChanged: (item, selected) =>
                _toggleLogged(probationActions, item, selected, 'Probation'),
          ),
        ],
      ),
    );
  }

  Widget _referralsSection() {
    final filtersSelected = referralFilters.isNotEmpty;
    final filtered = filtersSelected
        ? _filteredReferrals()
        : const <_Referral>[];

    return SectionCard(
      title: 'Referrals And Support',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Select a need or pathway first.',
            style: TextStyle(
              color: _caseworkMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _ChipPicker(
            options: _socialSupportOptions,
            selected: referralFilters,
            onChanged: (item, selected) => _toggleLogged(
              referralFilters,
              item,
              selected,
              'Referral filter',
            ),
          ),
          const SizedBox(height: 10),
          _ChipPicker(
            options: _referralFilterOptions,
            selected: referralFilters,
            onChanged: (item, selected) => _toggleLogged(
              referralFilters,
              item,
              selected,
              'Referral filter',
            ),
          ),
          const SizedBox(height: 14),
          if (!filtersSelected)
            const Text(
              'Services will appear after you choose a filter.',
              style: TextStyle(color: _caseworkMuted),
            )
          else ...[
            Row(
              children: [
                Text(
                  '${filtered.length} services shown',
                  style: const TextStyle(
                    color: _caseworkMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      referralFilters.clear();
                    });
                    unawaited(_saveDraft());
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Reset'),
                ),
              ],
            ),
            if (filtered.isEmpty)
              const Text(
                'No services match these filters.',
                style: TextStyle(color: _caseworkMuted),
              )
            else
              for (final referral in filtered)
                _ReferralTile(
                  referral: referral,
                  selected: _isReferralSelected(referral),
                  selectedProgrammes: _selectedReferralProgrammes(referral),
                  onToggle: () => _toggleReferralAgency(referral),
                  onProgrammeToggle: (programme, selected) =>
                      _toggleReferralProgramme(referral, programme, selected),
                ),
          ],
        ],
      ),
    );
  }

  Widget _fileSection(String noteFile) {
    return SectionCard(
      title: 'Live Note Output',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DropdownInput(
            label: 'File style',
            value: noteType,
            values: _noteTypes,
            onChanged: (value) {
              setState(() => noteType = value);
              unawaited(_saveDraft());
            },
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(minHeight: 320),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF101827),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF34405F)),
            ),
            child: SelectableText(
              noteFile,
              style: const TextStyle(
                color: Color(0xFFE7ECFA),
                height: 1.45,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _copyNote(noteFile),
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy Note File'),
          ),
        ],
      ),
    );
  }

  void _applyUrgencyAction(_UrgencyAction action) {
    setState(() {
      urgency = action.urgency;
      noteType = action.noteType;
      socialHousingRating = action.socialHousingRating ?? socialHousingRating;
      probationStatus = action.probationStatus ?? probationStatus;
      deadlineController.text = action.deadline;
      presentingNeeds.addAll(action.presentingNeeds);
      situationUnderstanding.addAll(action.situationUnderstanding);
      immediateSafety.addAll(action.immediateSafety);
      documents.addAll(action.documents);
      msdCriteria.addAll(action.msdCriteria);
      msdAdvocacy.addAll(action.msdAdvocacy);
      socialHousing.addAll(action.socialHousing);
      housingApplications.addAll(action.housingApplications);
      accommodationOptions.addAll(action.accommodationOptions);
      probationActions.addAll(action.probationActions);
      referrals.addAll(action.referrals);
      roadblocks.addAll(action.roadblocks);
      focus = action.focus;
    });
    unawaited(_saveDraft());
    _log(action.logText, action.logCategory);
  }

  void _applyQuickLog(_QuickLogAction action) {
    _log(action.action, action.category);
  }

  void _toggleLogged(
    Set<String> selected,
    String item,
    bool shouldSelect,
    String category,
  ) {
    setState(() {
      if (shouldSelect) {
        selected.add(item);
      } else {
        selected.remove(item);
      }
    });

    if (_requestCategories.contains(category)) {
      _recordRequest(
        category: category,
        request: item,
        status: shouldSelect ? 'Requested' : 'Removed',
      );
      return;
    }

    unawaited(_saveDraft());
  }

  List<_Referral> _filteredReferrals() {
    return [
      for (final referral in _referralOptions)
        if (_matchesReferralGroup(referral, referralFilters)) referral,
    ];
  }

  bool _matchesReferralGroup(_Referral referral, Set<String> filters) {
    if (filters.isEmpty) return true;

    final searchable = [
      referral.name,
      referral.category,
      referral.fit,
      ...referral.programmes,
      ...referral.criteria,
    ].join(' ').toLowerCase();

    return filters.any((filter) {
      final keywords = _referralFilterKeywords[filter] ?? [filter];
      return keywords.any(
        (keyword) => searchable.contains(keyword.toLowerCase()),
      );
    });
  }

  bool _isReferralSelected(_Referral referral) {
    return referrals.contains(referral.name) ||
        referral.programmes.any(
          (programme) =>
              referrals.contains(_referralProgrammeLabel(referral, programme)),
        );
  }

  Set<String> _selectedReferralProgrammes(_Referral referral) {
    return {
      for (final programme in referral.programmes)
        if (referrals.contains(_referralProgrammeLabel(referral, programme)))
          programme,
    };
  }

  void _toggleReferralAgency(_Referral referral) {
    _setReferralAgency(referral, !_isReferralSelected(referral));
  }

  void _setReferralAgency(_Referral referral, bool shouldSelect) {
    setState(() {
      referrals.remove(referral.name);
      for (final programme in referral.programmes) {
        referrals.remove(_referralProgrammeLabel(referral, programme));
      }
      if (shouldSelect) {
        referrals.add(referral.name);
      }
    });

    _recordRequest(
      category: 'Referral',
      request: referral.name,
      status: shouldSelect ? 'Requested' : 'Removed',
    );
  }

  void _toggleReferralProgramme(
    _Referral referral,
    String programme,
    bool shouldSelect,
  ) {
    final item = _referralProgrammeLabel(referral, programme);

    setState(() {
      referrals.remove(referral.name);
      if (shouldSelect) {
        referrals.add(item);
      } else {
        referrals.remove(item);
      }
    });

    _recordRequest(
      category: 'Programme',
      request: item,
      status: shouldSelect ? 'Requested' : 'Removed',
    );
  }

  String _referralProgrammeLabel(_Referral referral, String programme) {
    return '${referral.name} - $programme';
  }

  void _log(String action, String category) {
    setState(() {
      actionLog.insert(
        0,
        _ActionLogEntry(
          time: DateTime.now(),
          category: category,
          action: action,
        ),
      );
    });
    unawaited(_saveDraft());
  }

  void _recordRequest({
    required String category,
    required String request,
    required String status,
  }) {
    setState(() {
      requestHistory.insert(
        0,
        _RequestHistoryEntry(
          time: DateTime.now(),
          category: category,
          request: request,
          status: status,
        ),
      );
    });
    unawaited(_saveDraft());
  }

  Future<void> _copyNote(String note) async {
    await Clipboard.setData(ClipboardData(text: note));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('Casework note file copied')),
      );
  }

  void _saveSnapshot() {
    _log('Casework file saved', 'File');
  }

  Future<void> _showCreateProfileDialog() async {
    final controller = TextEditingController(text: _nextProfileCode());

    final code = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New case file'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Case code',
              hintText: 'CASE-002',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    final cleaned = _cleanProfileCode(code);
    if (cleaned == null) return;

    await _saveDraft();
    if (!mounted) return;

    setState(() {
      profiles.putIfAbsent(
        cleaned,
        () => _CaseProfileRecord(
          code: cleaned,
          updatedAt: DateTime.now(),
          data: {'clientCode': cleaned},
        ),
      );
      _resetCurrentCase(cleaned);
      activeProfileCode = cleaned;
    });
    await _saveDraft();
  }

  Future<void> _switchProfile(String code) async {
    if (code == activeProfileCode || !profiles.containsKey(code)) return;

    await _saveDraft();
    if (!mounted) return;

    setState(() {
      _applyCaseData(profiles[code]!.data, code);
    });
  }

  Future<void> _confirmDeleteProfile() async {
    if (profiles.length <= 1) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Keep at least one case file.')),
        );
      return;
    }

    final code = activeProfileCode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete $code?'),
          content: const Text(
            'This removes the current case file from this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      profiles.remove(code);
      final nextCode = _sortedProfileCodes.first;
      _applyCaseData(profiles[nextCode]!.data, nextCode);
    });
    await _persistProfiles();
  }

  String _nextProfileCode() {
    var index = profiles.length + 1;
    while (true) {
      final code = 'CASE-${index.toString().padLeft(3, '0')}';
      if (!profiles.containsKey(code)) return code;
      index++;
    }
  }

  String? _cleanProfileCode(String? value) {
    final cleaned = value?.trim().toUpperCase();
    if (cleaned == null || cleaned.isEmpty) return null;
    return cleaned;
  }

  Future<void> _confirmClearDraft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Clear $activeProfileCode?'),
          content: const Text(
            'This clears the current profile content and history. The client '
            'code remains available.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await _clearDraft();
  }

  Future<void> _clearDraft() async {
    setState(() {
      _resetCurrentCase(activeProfileCode);
    });

    await _saveDraft();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text('$activeProfileCode case file cleared')),
      );
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final rawProfiles = prefs.getString(_profilesKey);
    final loadedProfiles = <String, _CaseProfileRecord>{};
    String? loadedActiveCode;

    if (rawProfiles != null && rawProfiles.isNotEmpty) {
      final decoded = jsonDecode(rawProfiles);
      if (decoded is Map<String, Object?>) {
        loadedActiveCode = decoded['activeProfileCode'] as String?;
        final storedProfiles = decoded['profiles'];
        if (storedProfiles is Map<String, Object?>) {
          for (final entry in storedProfiles.entries) {
            final value = entry.value;
            if (value is! Map<String, Object?>) continue;
            final data = value['data'];
            if (data is! Map<String, Object?>) continue;
            loadedProfiles[entry.key] = _CaseProfileRecord(
              code: entry.key,
              updatedAt:
                  DateTime.tryParse((value['updatedAt'] as String?) ?? '') ??
                  DateTime.now(),
              data: Map<String, Object?>.from(data),
            );
          }
        }
      }
    }

    if (loadedProfiles.isEmpty) {
      final legacyRaw = prefs.getString(_legacyDraftKey);
      Map<String, Object?> legacyData = {};
      if (legacyRaw != null && legacyRaw.isNotEmpty) {
        final decoded = jsonDecode(legacyRaw);
        if (decoded is Map<String, Object?>) {
          legacyData = Map<String, Object?>.from(decoded);
        }
      }
      legacyData['clientCode'] = 'CASE-001';
      legacyData.remove('clientInitials');
      loadedProfiles['CASE-001'] = _CaseProfileRecord(
        code: 'CASE-001',
        updatedAt: DateTime.now(),
        data: legacyData,
      );
      loadedActiveCode = 'CASE-001';
    }

    final selectedCode = loadedProfiles.containsKey(loadedActiveCode)
        ? loadedActiveCode!
        : loadedProfiles.keys.first;
    if (!mounted) return;

    setState(() {
      profiles
        ..clear()
        ..addAll(loadedProfiles);
      activeProfileCode = selectedCode;
      _applyCaseData(profiles[selectedCode]!.data, selectedCode);
    });
    await _persistProfiles();
  }

  Future<void> _saveDraft() async {
    profiles[activeProfileCode] = _CaseProfileRecord(
      code: activeProfileCode,
      updatedAt: DateTime.now(),
      data: _currentCaseData(),
    );
    await _persistProfiles();
  }

  Future<void> _persistProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _profilesKey,
      jsonEncode({
        'activeProfileCode': activeProfileCode,
        'profiles': {
          for (final entry in profiles.entries)
            entry.key: {
              'updatedAt': entry.value.updatedAt.toIso8601String(),
              'data': entry.value.data,
            },
        },
      }),
    );
  }

  Map<String, Object?> _currentCaseData() {
    return {
      'clientCode': activeProfileCode,
      'workerInitials': workerInitialsController.text.trim(),
      'deadline': deadlineController.text.trim(),
      'additionalContext': additionalContextController.text.trim(),
      'urgency': urgency,
      'contact': contact,
      'consent': consent,
      'noteType': noteType,
      'socialHousingRating': socialHousingRating,
      'probationStatus': probationStatus,
      'presentingNeeds': presentingNeeds.toList(),
      'situationUnderstanding': situationUnderstanding.toList(),
      'immediateSafety': immediateSafety.toList(),
      'documents': documents.toList(),
      'msdCriteria': msdCriteria.toList(),
      'msdAdvocacy': msdAdvocacy.toList(),
      'socialHousing': socialHousing.toList(),
      'housingApplications': housingApplications.toList(),
      'accommodationOptions': accommodationOptions.toList(),
      'probationActions': probationActions.toList(),
      'referrals': referrals.toList(),
      'supportNeeds': supportNeeds.toList(),
      'referralFilters': referralFilters.toList(),
      'roadblocks': roadblocks.toList(),
      'updatedFocuses': updatedFocuses.map((focus) => focus.name).toList(),
      'completedFocuses': completedFocuses.map((focus) => focus.name).toList(),
      'actionLog': [
        for (final entry in actionLog)
          {
            'time': entry.time.toIso8601String(),
            'category': entry.category,
            'action': entry.action,
          },
      ],
      'requestHistory': [
        for (final entry in requestHistory)
          {
            'time': entry.time.toIso8601String(),
            'category': entry.category,
            'request': entry.request,
            'status': entry.status,
          },
      ],
    };
  }

  void _applyCaseData(Map<String, Object?> data, String code) {
    activeProfileCode = code;
    clientInitialsController.text = code;
    workerInitialsController.text = (data['workerInitials'] as String?) ?? '';
    deadlineController.text = (data['deadline'] as String?) ?? 'Today';
    additionalContextController.text =
        (data['additionalContext'] as String?) ?? '';
    urgency = (data['urgency'] as String?) ?? 'high';
    contact = (data['contact'] as String?) ?? 'Walk-in';
    consent = (data['consent'] as String?) ?? 'Verbal consent given';
    noteType = (data['noteType'] as String?) ?? 'Peer support housing note';
    socialHousingRating =
        (data['socialHousingRating'] as String?) ?? 'Not checked';
    probationStatus = (data['probationStatus'] as String?) ?? 'Not applicable';
    _replaceSet(presentingNeeds, data['presentingNeeds']);
    _replaceSet(situationUnderstanding, data['situationUnderstanding']);
    _replaceSet(immediateSafety, data['immediateSafety']);
    _replaceSet(documents, data['documents']);
    _replaceSet(msdCriteria, data['msdCriteria']);
    _replaceSet(msdAdvocacy, data['msdAdvocacy']);
    _replaceSet(socialHousing, data['socialHousing']);
    _replaceSet(housingApplications, data['housingApplications']);
    _replaceSet(accommodationOptions, data['accommodationOptions']);
    _replaceSet(probationActions, data['probationActions']);
    _replaceSet(referrals, data['referrals']);
    _replaceSet(supportNeeds, data['supportNeeds']);
    _replaceSet(referralFilters, data['referralFilters']);
    _replaceSet(roadblocks, data['roadblocks']);
    _replaceFocusSet(updatedFocuses, data['updatedFocuses']);
    _replaceFocusSet(completedFocuses, data['completedFocuses']);
    actionLog
      ..clear()
      ..addAll(_readActionLog(data['actionLog']));
    requestHistory
      ..clear()
      ..addAll(_readRequestHistory(data['requestHistory']));
    focus = _CaseworkFocus.walkIn;
  }

  void _resetCurrentCase(String code) {
    clientInitialsController.text = code;
    workerInitialsController.clear();
    deadlineController.text = 'Today';
    additionalContextController.clear();
    focus = _CaseworkFocus.walkIn;
    urgency = 'high';
    contact = 'Walk-in';
    consent = 'Verbal consent given';
    noteType = 'Peer support housing note';
    socialHousingRating = 'Not checked';
    probationStatus = 'Not applicable';
    presentingNeeds.clear();
    situationUnderstanding.clear();
    immediateSafety.clear();
    documents.clear();
    msdCriteria.clear();
    msdAdvocacy.clear();
    socialHousing.clear();
    housingApplications.clear();
    accommodationOptions.clear();
    probationActions.clear();
    referrals.clear();
    supportNeeds.clear();
    referralFilters.clear();
    roadblocks.clear();
    updatedFocuses.clear();
    completedFocuses.clear();
    actionLog.clear();
    requestHistory.clear();
  }

  void _replaceSet(Set<String> target, Object? value) {
    target
      ..clear()
      ..addAll(_readStringList(value));
  }

  void _replaceFocusSet(Set<_CaseworkFocus> target, Object? value) {
    target
      ..clear()
      ..addAll(
        _readStringList(value).map(_focusFromName).whereType<_CaseworkFocus>(),
      );
  }

  _CaseworkFocus? _focusFromName(String name) {
    for (final focus in _CaseworkFocus.values) {
      if (focus.name == name) return focus;
    }
    return null;
  }

  void _toggleUpdated(Iterable<_CaseworkFocus> focuses) {
    final values = focuses.toSet();
    setState(() {
      if (values.every(updatedFocuses.contains)) {
        updatedFocuses.removeAll(values);
      } else {
        updatedFocuses.addAll(values);
      }
    });
    unawaited(_saveDraft());
  }

  void _toggleCompleted(Iterable<_CaseworkFocus> focuses) {
    final values = focuses.toSet();
    setState(() {
      if (values.every(completedFocuses.contains)) {
        completedFocuses.removeAll(values);
      } else {
        completedFocuses.addAll(values);
        updatedFocuses.addAll(values);
      }
    });
    unawaited(_saveDraft());
  }

  List<String> _readStringList(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is String) item,
    ];
  }

  List<_ActionLogEntry> _readActionLog(Object? value) {
    if (value is! List) return const [];

    return [
      for (final item in value)
        if (item is Map<String, Object?>)
          _ActionLogEntry(
            time:
                DateTime.tryParse((item['time'] as String?) ?? '') ??
                DateTime.now(),
            category: (item['category'] as String?) ?? 'Action',
            action: (item['action'] as String?) ?? '',
          ),
    ];
  }

  List<_RequestHistoryEntry> _readRequestHistory(Object? value) {
    if (value is! List) return const [];

    return [
      for (final item in value)
        if (item is Map<String, Object?>)
          _RequestHistoryEntry(
            time:
                DateTime.tryParse((item['time'] as String?) ?? '') ??
                DateTime.now(),
            category: (item['category'] as String?) ?? 'Request',
            request: (item['request'] as String?) ?? '',
            status: (item['status'] as String?) ?? 'Updated',
          ),
    ];
  }

  String _buildNoteFile() {
    final client = _valueOr(clientInitialsController.text, '[initials]');
    final worker = _valueOr(workerInitialsController.text, '[worker initials]');
    final deadline = _valueOr(deadlineController.text, '[next deadline]');
    final openSteps = _openNextSteps();
    final logLines = _noteActionLogLines();
    final mainNotes = additionalContextController.text.trim();
    final keyActions = [
      ...msdAdvocacy,
      ...housingApplications,
      ...accommodationOptions,
      ...probationActions,
    ];
    final housingLines = [
      if (socialHousingRating != 'Not checked')
        'Social housing status: $socialHousingRating',
      ...socialHousing,
      ...housingApplications,
      ...accommodationOptions,
    ];
    final probationLines = [
      if (probationStatus != 'Not applicable')
        'Probation/bail status: $probationStatus',
      ...probationActions,
    ];
    final buffer = StringBuffer()
      ..writeln(noteType)
      ..writeln('Date/time: ${_dateTime(DateTime.now())}')
      ..writeln('Person: $client')
      ..writeln('Worker: $worker')
      ..writeln('Contact: $contact')
      ..writeln('Consent: $consent')
      ..writeln('Urgency: ${urgency.toUpperCase()}')
      ..writeln('Next check-in: $deadline');

    switch (noteType) {
      case 'MSD call support note':
        _addNoteSection(buffer, 'Reason For MSD Contact', presentingNeeds);
        _addNoteSection(buffer, 'Current Accommodation And Alternatives', [
          ...situationUnderstanding,
          ...accommodationOptions,
        ]);
        _addNoteSection(buffer, 'Emergency Housing Criteria', msdCriteria);
        _addNoteSection(buffer, 'Evidence Ready', documents);
        _addNoteSection(buffer, 'Request / Advocacy Made', msdAdvocacy);
        _addNoteSection(buffer, 'Safety Or Access Factors', immediateSafety);
        _addNoteSection(buffer, 'MSD Outcome / Actions', logLines);
        _addNoteSection(buffer, 'Follow-Up Required', openSteps.take(6));
        break;
      case 'CMM / MSD handover note':
        _addNoteSection(buffer, 'Reason For Handover', presentingNeeds);
        _addNoteSection(
          buffer,
          'Current Housing Position',
          situationUnderstanding,
        );
        _addNoteSection(buffer, 'Risks / Barriers', [
          ...immediateSafety,
          ...roadblocks,
        ]);
        _addNoteSection(buffer, 'MSD Work Completed', [
          ...msdCriteria,
          ...msdAdvocacy,
        ]);
        _addNoteSection(buffer, 'Evidence Available', documents);
        _addNoteSection(buffer, 'Requested Services / Programmes', referrals);
        _addNoteSection(buffer, 'Actions And Next Steps', [
          ...logLines,
          ...openSteps.take(5),
        ]);
        break;
      case 'Housing application support note':
        _addNoteSection(buffer, 'Housing Goal / Current Position', [
          ...presentingNeeds,
          ...situationUnderstanding,
        ]);
        _addNoteSection(buffer, 'Applications / Housing Pathway', housingLines);
        _addNoteSection(buffer, 'Evidence Ready', documents);
        _addNoteSection(buffer, 'Barriers Affecting Applications', [
          ...roadblocks,
          ...probationLines,
        ]);
        _addNoteSection(buffer, 'Agencies / Programmes', referrals);
        _addNoteSection(buffer, 'Actions Completed', logLines);
        _addNoteSection(buffer, 'Application Follow-Up', openSteps.take(6));
        break;
      case 'Referral and next-steps note':
        _addNoteSection(buffer, 'Reason Support Is Needed', [
          ...presentingNeeds,
          ...supportNeeds,
        ]);
        _addNoteSection(buffer, 'Relevant Situation / Risks', [
          ...situationUnderstanding,
          ...immediateSafety,
        ]);
        _addNoteSection(buffer, 'Selected Services / Programmes', referrals);
        _addNoteSection(buffer, 'Information / Evidence Shared', documents);
        _addNoteSection(buffer, 'Contact / Actions Taken', logLines);
        _addNoteSection(buffer, 'Agreed Next Steps', openSteps.take(6));
        break;
      default:
        _addNoteSection(buffer, 'Presenting Situation', presentingNeeds);
        _addNoteSection(
          buffer,
          'Housing Position / Context',
          situationUnderstanding,
        );
        _addNoteSection(buffer, 'Safety And Immediate Checks', immediateSafety);
        _addNoteSection(buffer, 'Social Support Needs', supportNeeds);
        _addNoteSection(buffer, 'Evidence / Documents Checked', documents);
        _addNoteSection(buffer, 'MSD / CMM Advocacy', msdAdvocacy);
        _addNoteSection(buffer, 'Housing Pathway', housingLines);
        _addNoteSection(buffer, 'Corrections / Probation', probationLines);
        _addNoteSection(buffer, 'Referrals / Supports', referrals);
        _addNoteSection(
          buffer,
          'Roadblocks / Follow-Up Safeguards',
          roadblocks,
        );
        _addNoteSection(buffer, 'Practical Actions Logged', logLines);
        if (keyActions.isNotEmpty && logLines.isEmpty) {
          _addNoteSection(buffer, 'Practical Actions Identified', keyActions);
        }
        _addNoteSection(buffer, 'Still To Check', openSteps.take(6));
        break;
    }

    _addNoteSection(buffer, 'Main Notes', [mainNotes]);
    return buffer.toString().trim();
  }

  void _addNoteSection(
    StringBuffer buffer,
    String title,
    Iterable<String> values,
  ) {
    final cleaned = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    if (cleaned.isEmpty) return;

    buffer
      ..writeln()
      ..writeln(title)
      ..writeln(_lines(cleaned));
  }

  List<String> _noteActionLogLines() {
    return actionLog
        .where((entry) {
          final action = entry.action.trim();
          return !action.startsWith('Completed:') &&
              !action.startsWith('Reopened:');
        })
        .map(
          (entry) =>
              '${_dateTime(entry.time)} | ${entry.category} | ${entry.action}',
        )
        .toList();
  }

  List<String> _openNextSteps() {
    final steps = <String>[];

    final selectedContext = [
      ...presentingNeeds,
      ...situationUnderstanding,
    ].join(' ').toLowerCase();
    final housingCrisis = [
      'no safe place',
      'asked to leave',
      'cannot return',
      'emergency housing',
      'transitional housing',
      'motel',
      'couch-surfing',
      'leaving custody',
    ].any(selectedContext.contains);
    final msdPathway =
        housingCrisis ||
        noteType == 'MSD call support note' ||
        noteType == 'CMM / MSD handover note' ||
        msdCriteria.isNotEmpty ||
        msdAdvocacy.isNotEmpty;
    final housingApplicationPathway =
        noteType == 'Housing application support note' ||
        housingApplications.isNotEmpty ||
        socialHousing.isNotEmpty ||
        selectedContext.contains('public housing') ||
        selectedContext.contains('private rental') ||
        selectedContext.contains('tenancy');
    final safetyPathway =
        urgency == 'critical' ||
        selectedContext.contains('violence') ||
        selectedContext.contains('safety') ||
        immediateSafety.isNotEmpty;
    final probationPathway =
        selectedContext.contains('probation') ||
        selectedContext.contains('bail') ||
        probationStatus != 'Not applicable' ||
        probationActions.isNotEmpty;
    final referralPathway =
        noteType == 'Referral and next-steps note' ||
        supportNeeds.isNotEmpty ||
        referrals.isNotEmpty;

    if ((housingCrisis || housingApplicationPathway) &&
        situationUnderstanding.isEmpty) {
      steps.add('Confirm the current housing position');
    }

    if (housingCrisis || safetyPathway) {
      for (final item in _minimumSafetyChecks) {
        if (!immediateSafety.contains(item)) {
          steps.add('Complete safety check: $item');
        }
      }
    }

    if (msdPathway) {
      for (final item in _minimumMsdCriteriaChecks) {
        if (!msdCriteria.contains(item)) {
          steps.add('Check MSD criterion: $item');
        }
      }
      for (final item in _minimumDocumentChecks) {
        if (!documents.contains(item)) {
          steps.add('Collect/check document: $item');
        }
      }
      for (final item in _minimumMsdChecks) {
        if (!msdAdvocacy.contains(item)) {
          steps.add('Complete MSD/CMM action: $item');
        }
      }
    } else if (housingApplicationPathway) {
      for (final item in _minimumDocumentChecks) {
        if (!documents.contains(item)) {
          steps.add('Collect/check document: $item');
        }
      }
    }

    if (housingApplicationPathway && socialHousingRating == 'Not checked') {
      steps.add('Check social housing rating/status');
    }
    if (housingCrisis && accommodationOptions.isEmpty) {
      steps.add('Check a suitable accommodation option for tonight');
    }
    if (probationPathway && probationActions.isEmpty) {
      steps.add('Complete probation/bail address actions');
    }
    if (referralPathway && referrals.isEmpty) {
      steps.add('Select at least one referral/support pathway');
    }
    return steps;
  }

  String _lines(Iterable<String> values) {
    if (values.isEmpty) return '[not completed yet]';
    return values.map((value) => '- $value').join('\n');
  }

  String _valueOr(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String _dateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$minute';
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.onSave,
    required this.onNew,
    required this.onOutput,
    required this.onClear,
  });

  final VoidCallback onSave;
  final VoidCallback onNew;
  final VoidCallback onOutput;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_caseworkSurface, _caseworkInkSoft]),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: Offset(0, 2),
            color: Color(0x26000000),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            'Housing Casework',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Blenheim / Marlborough',
            style: TextStyle(color: Color(0xFFC7D8E7), fontSize: 12),
          ),
          const Spacer(),
          _TopBarButton(
            label: 'Save',
            icon: Icons.save_outlined,
            onTap: onSave,
          ),
          _TopBarButton(label: 'New Case', icon: Icons.add, onTap: onNew),
          _TopBarButton(
            label: 'Output',
            icon: Icons.description_outlined,
            onTap: onOutput,
          ),
          _TopBarButton(
            label: 'Clear Case',
            icon: Icons.delete_outline,
            danger: true,
            onTap: onClear,
          ),
        ],
      ),
    );
  }
}

class _CompactCaseworkHeader extends StatelessWidget {
  const _CompactCaseworkHeader({
    required this.onSave,
    required this.onNew,
    required this.onOutput,
    required this.onClear,
  });

  final VoidCallback onSave;
  final VoidCallback onNew;
  final VoidCallback onOutput;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _DesktopCard(
      title: 'Housing Casework',
      icon: Icons.home_work_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Blenheim / Marlborough',
            style: TextStyle(
              color: _caseworkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CompactHeaderButton(
                label: 'Save',
                icon: Icons.save_outlined,
                onTap: onSave,
              ),
              _CompactHeaderButton(
                label: 'New Case',
                icon: Icons.add,
                onTap: onNew,
              ),
              _CompactHeaderButton(
                label: 'Output',
                icon: Icons.description_outlined,
                onTap: onOutput,
              ),
              _CompactHeaderButton(
                label: 'Clear Case',
                icon: Icons.delete_outline,
                danger: true,
                onTap: onClear,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactHeaderButton extends StatelessWidget {
  const _CompactHeaderButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: danger ? const Color(0xFFFFB7B7) : _caseworkInk,
        side: BorderSide(
          color: danger ? const Color(0xFFFF5A5F) : _caseworkLine,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _CompactClientCard extends StatelessWidget {
  const _CompactClientCard({
    required this.clientInitialsController,
    required this.workerInitialsController,
    required this.deadlineController,
    required this.contact,
    required this.consent,
    required this.urgency,
    required this.noteType,
    required this.profileCodes,
    required this.activeProfileCode,
    required this.onProfileChanged,
    required this.onCreateProfile,
    required this.onContactChanged,
    required this.onConsentChanged,
    required this.onUrgencyChanged,
    required this.onNoteTypeChanged,
    required this.onTextChanged,
  });

  final TextEditingController clientInitialsController;
  final TextEditingController workerInitialsController;
  final TextEditingController deadlineController;
  final String contact;
  final String consent;
  final String urgency;
  final String noteType;
  final List<String> profileCodes;
  final String activeProfileCode;
  final ValueChanged<String> onProfileChanged;
  final VoidCallback onCreateProfile;
  final ValueChanged<String> onContactChanged;
  final ValueChanged<String> onConsentChanged;
  final ValueChanged<String> onUrgencyChanged;
  final ValueChanged<String> onNoteTypeChanged;
  final ValueChanged<String> onTextChanged;

  @override
  Widget build(BuildContext context) {
    return _DesktopCard(
      title: 'Client / whanau',
      icon: Icons.person_outline_rounded,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DesktopDropdown(
                  label: 'Case file',
                  value: activeProfileCode,
                  values: profileCodes,
                  onChanged: onProfileChanged,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: IconButton.filledTonal(
                  tooltip: 'New case',
                  onPressed: onCreateProfile,
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
            ],
          ),
          _DesktopTextField(
            controller: clientInitialsController,
            label: 'Case code',
            hint: 'CASE-001',
            onChanged: onTextChanged,
          ),
          _DesktopTextField(
            controller: workerInitialsController,
            label: 'Worker',
            hint: 'Your name',
            onChanged: onTextChanged,
          ),
          _DesktopDropdown(
            label: 'Contact Type',
            value: contact,
            values: _contacts,
            onChanged: onContactChanged,
          ),
          _DesktopDropdown(
            label: 'Consent',
            value: consent,
            values: _consents,
            onChanged: onConsentChanged,
          ),
          _DesktopDropdown(
            label: 'Risk Level',
            value: urgency,
            values: _urgencyOptions.map((option) => option.value).toList(),
            onChanged: onUrgencyChanged,
          ),
          _DesktopTextField(
            controller: deadlineController,
            label: 'Deadline / Urgency',
            hint: 'e.g. Tonight, 3 days, EH expires Fri',
            onChanged: onTextChanged,
          ),
          _DesktopDropdown(
            label: 'Note Style',
            value: noteType,
            values: _noteTypes,
            onChanged: onNoteTypeChanged,
          ),
        ],
      ),
    );
  }
}

class _CompactLiveCard extends StatelessWidget {
  const _CompactLiveCard({
    required this.urgency,
    required this.openStepCount,
    required this.actionCount,
    required this.latestAction,
    required this.requestHistory,
    required this.onQuickLog,
    required this.onClear,
  });

  final String urgency;
  final int openStepCount;
  final int actionCount;
  final _ActionLogEntry? latestAction;
  final List<_RequestHistoryEntry> requestHistory;
  final ValueChanged<_QuickLogAction> onQuickLog;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _DesktopCard(
      title: 'Live Case File',
      icon: Icons.history_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LightStatusPill(label: 'Urgency', value: urgency.toUpperCase()),
              _LightStatusPill(label: 'Open steps', value: '$openStepCount'),
              _LightStatusPill(label: 'Logged', value: '$actionCount'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _caseworkPanel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _caseworkLine),
            ),
            child: Text(
              latestAction == null
                  ? 'No action timestamped yet.'
                  : '${_shortTime(latestAction!.time)} | '
                        '${latestAction!.category} | ${latestAction!.action}',
              style: const TextStyle(color: _caseworkInk, height: 1.35),
            ),
          ),
          const SizedBox(height: 12),
          if (requestHistory.isNotEmpty) ...[
            _RequestHistoryPreview(history: requestHistory),
            const SizedBox(height: 12),
          ],
          _ActionButtonWrap(actions: _quickLogActions, onSelected: onQuickLog),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Clear / new'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFA23A3A),
              side: const BorderSide(color: Color(0xFFEAA1A1)),
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }

  String _shortTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _CompactFocusBar extends StatelessWidget {
  const _CompactFocusBar({
    required this.current,
    required this.updatedFocuses,
    required this.completedFocuses,
    required this.onChanged,
    required this.onUpdatedToggle,
    required this.onCompletedToggle,
  });

  final _CaseworkFocus current;
  final Set<_CaseworkFocus> updatedFocuses;
  final Set<_CaseworkFocus> completedFocuses;
  final ValueChanged<_CaseworkFocus> onChanged;
  final ValueChanged<_CaseworkFocus> onUpdatedToggle;
  final ValueChanged<_CaseworkFocus> onCompletedToggle;

  @override
  Widget build(BuildContext context) {
    return _DesktopCard(
      title: 'Workflow',
      icon: Icons.account_tree_outlined,
      child: Column(
        children: [
          const _StatusLegend(),
          const SizedBox(height: 10),
          for (final item in _focusItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CompactFocusTab(
                item: item,
                selected: current == item.focus,
                updated: updatedFocuses.contains(item.focus),
                completed: completedFocuses.contains(item.focus),
                onTap: () => onChanged(item.focus),
                onUpdatedToggle: () => onUpdatedToggle(item.focus),
                onCompletedToggle: () => onCompletedToggle(item.focus),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompactFocusTab extends StatelessWidget {
  const _CompactFocusTab({
    required this.item,
    required this.selected,
    required this.updated,
    required this.completed,
    required this.onTap,
    required this.onUpdatedToggle,
    required this.onCompletedToggle,
  });

  final _FocusItem item;
  final bool selected;
  final bool updated;
  final bool completed;
  final VoidCallback onTap;
  final VoidCallback onUpdatedToggle;
  final VoidCallback onCompletedToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _caseworkSelected : _caseworkInkSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? _caseworkBlue : _caseworkLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Icon(
                      item.icon,
                      size: 18,
                      color: selected ? _caseworkBlue : _caseworkMuted,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: _caseworkInk,
                        fontWeight: selected
                            ? FontWeight.w900
                            : FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _FocusStatusButton(
            key: ValueKey('casework-${item.focus.name}-updated'),
            label: item.label,
            status: 'updated',
            icon: Icons.update_rounded,
            color: _caseworkUpdated,
            active: updated,
            onPressed: onUpdatedToggle,
          ),
          _FocusStatusButton(
            key: ValueKey('casework-${item.focus.name}-completed'),
            label: item.label,
            status: 'completed',
            icon: Icons.check_circle_rounded,
            color: _caseworkCompleted,
            active: completed,
            onPressed: onCompletedToggle,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _FocusStatusButton extends StatelessWidget {
  const _FocusStatusButton({
    super.key,
    required this.label,
    required this.status,
    required this.icon,
    required this.color,
    required this.active,
    required this.onPressed,
  });

  final String label;
  final String status;
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final action = active ? 'Clear' : 'Mark';
    return IconButton(
      tooltip: '$action $label $status',
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      icon: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? color : _caseworkLine),
        ),
        child: Icon(icon, size: 17, color: active ? color : _caseworkMuted),
      ),
    );
  }
}

class _StatusLegend extends StatelessWidget {
  const _StatusLegend();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.update_rounded, size: 15, color: _caseworkUpdated),
        SizedBox(width: 5),
        Text(
          'Updated',
          style: TextStyle(
            color: _caseworkUpdated,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(width: 14),
        Icon(Icons.check_circle_rounded, size: 15, color: _caseworkCompleted),
        SizedBox(width: 5),
        Text(
          'Completed',
          style: TextStyle(
            color: _caseworkCompleted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CompactNoteOutput extends StatelessWidget {
  const _CompactNoteOutput({
    required this.noteType,
    required this.noteFile,
    required this.onNoteTypeChanged,
    required this.onCopy,
  });

  final String noteType;
  final String noteFile;
  final ValueChanged<String> onNoteTypeChanged;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return _DesktopCard(
      title: 'Note Output',
      icon: Icons.description_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DesktopDropdown(
            label: 'Note style',
            value: noteType,
            values: _noteTypes,
            onChanged: onNoteTypeChanged,
          ),
          OutlinedButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_outlined, size: 16),
            label: const Text('Copy note'),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _caseworkPanel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _caseworkLine),
            ),
            child: SelectableText(
              noteFile,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.5,
                color: _caseworkInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LightStatusPill extends StatelessWidget {
  const _LightStatusPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: _caseworkSelected,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _caseworkLine),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: _caseworkInk,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RequestHistoryPreview extends StatelessWidget {
  const _RequestHistoryPreview({required this.history});

  final List<_RequestHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _caseworkPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _caseworkLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Latest requests',
            style: TextStyle(color: _caseworkInk, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (final entry in history.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${entry.status}: ${entry.request}',
                style: const TextStyle(
                  color: _caseworkMuted,
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopBarButton extends StatelessWidget {
  const _TopBarButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: danger
              ? const Color(0xFF88464B)
              : const Color(0x33202A40),
          side: const BorderSide(color: Color(0xFF77A7C7)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _DesktopWorkflowRail extends StatelessWidget {
  const _DesktopWorkflowRail({
    required this.current,
    required this.updatedFocuses,
    required this.completedFocuses,
    required this.onChanged,
    required this.onUpdatedToggle,
    required this.onCompletedToggle,
  });

  final _CaseworkFocus current;
  final Set<_CaseworkFocus> updatedFocuses;
  final Set<_CaseworkFocus> completedFocuses;
  final ValueChanged<_CaseworkFocus> onChanged;
  final ValueChanged<Iterable<_CaseworkFocus>> onUpdatedToggle;
  final ValueChanged<Iterable<_CaseworkFocus>> onCompletedToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: _caseworkSurface,
        border: Border(right: BorderSide(color: _caseworkLine)),
      ),
      child: ListView(
        children: [
          const _RailHeader('Workflow'),
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 2, 14, 8),
            child: _StatusLegend(),
          ),
          _RailItem(
            icon: Icons.sync_alt_outlined,
            label: 'Case Flow',
            statusFocuses: const [
              _CaseworkFocus.walkIn,
              _CaseworkFocus.situation,
            ],
            selected:
                current == _CaseworkFocus.walkIn ||
                current == _CaseworkFocus.situation,
            onTap: () => onChanged(_CaseworkFocus.walkIn),
            updatedFocuses: updatedFocuses,
            completedFocuses: completedFocuses,
            onUpdatedToggle: onUpdatedToggle,
            onCompletedToggle: onCompletedToggle,
          ),
          _RailItem(
            icon: Icons.apartment_outlined,
            label: 'Housing + MSD',
            statusFocuses: const [_CaseworkFocus.msd],
            selected: current == _CaseworkFocus.msd,
            onTap: () => onChanged(_CaseworkFocus.msd),
            updatedFocuses: updatedFocuses,
            completedFocuses: completedFocuses,
            onUpdatedToggle: onUpdatedToggle,
            onCompletedToggle: onCompletedToggle,
          ),
          _RailItem(
            icon: Icons.check_box_outlined,
            label: 'Evidence Gathered',
            statusFocuses: const [_CaseworkFocus.documents],
            selected: current == _CaseworkFocus.documents,
            onTap: () => onChanged(_CaseworkFocus.documents),
            updatedFocuses: updatedFocuses,
            completedFocuses: completedFocuses,
            onUpdatedToggle: onUpdatedToggle,
            onCompletedToggle: onCompletedToggle,
          ),
          _RailItem(
            icon: Icons.explore_outlined,
            label: 'CMM Housing',
            statusFocuses: const [
              _CaseworkFocus.housing,
              _CaseworkFocus.accommodation,
            ],
            selected:
                current == _CaseworkFocus.housing ||
                current == _CaseworkFocus.accommodation,
            onTap: () => onChanged(_CaseworkFocus.housing),
            updatedFocuses: updatedFocuses,
            completedFocuses: completedFocuses,
            onUpdatedToggle: onUpdatedToggle,
            onCompletedToggle: onCompletedToggle,
          ),
          _RailItem(
            icon: Icons.phone_forwarded_outlined,
            label: 'Programmes + Referrals',
            statusFocuses: const [_CaseworkFocus.referrals],
            selected: current == _CaseworkFocus.referrals,
            onTap: () => onChanged(_CaseworkFocus.referrals),
            updatedFocuses: updatedFocuses,
            completedFocuses: completedFocuses,
            onUpdatedToggle: onUpdatedToggle,
            onCompletedToggle: onCompletedToggle,
          ),
          _RailItem(
            icon: Icons.handshake_outlined,
            label: 'Social Support',
            statusFocuses: const [_CaseworkFocus.safety],
            selected: current == _CaseworkFocus.safety,
            onTap: () => onChanged(_CaseworkFocus.safety),
            updatedFocuses: updatedFocuses,
            completedFocuses: completedFocuses,
            onUpdatedToggle: onUpdatedToggle,
            onCompletedToggle: onCompletedToggle,
          ),
          _RailItem(
            icon: Icons.menu_book_outlined,
            label: 'Diary + Objections',
            statusFocuses: const [_CaseworkFocus.probation],
            selected: current == _CaseworkFocus.probation,
            onTap: () => onChanged(_CaseworkFocus.probation),
            updatedFocuses: updatedFocuses,
            completedFocuses: completedFocuses,
            onUpdatedToggle: onUpdatedToggle,
            onCompletedToggle: onCompletedToggle,
          ),
          const Divider(height: 28, color: _caseworkLine),
          const _RailHeader('Output'),
          _RailItem(
            icon: Icons.description_outlined,
            label: 'Build Note',
            statusFocuses: const [_CaseworkFocus.file],
            selected: current == _CaseworkFocus.file,
            onTap: () => onChanged(_CaseworkFocus.file),
            updatedFocuses: updatedFocuses,
            completedFocuses: completedFocuses,
            onUpdatedToggle: onUpdatedToggle,
            onCompletedToggle: onCompletedToggle,
          ),
        ],
      ),
    );
  }
}

class _RailHeader extends StatelessWidget {
  const _RailHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: _caseworkMuted,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.label,
    required this.statusFocuses,
    required this.selected,
    required this.onTap,
    required this.updatedFocuses,
    required this.completedFocuses,
    required this.onUpdatedToggle,
    required this.onCompletedToggle,
  });

  final IconData icon;
  final String label;
  final List<_CaseworkFocus> statusFocuses;
  final bool selected;
  final VoidCallback onTap;
  final Set<_CaseworkFocus> updatedFocuses;
  final Set<_CaseworkFocus> completedFocuses;
  final ValueChanged<Iterable<_CaseworkFocus>> onUpdatedToggle;
  final ValueChanged<Iterable<_CaseworkFocus>> onCompletedToggle;

  @override
  Widget build(BuildContext context) {
    final updated = statusFocuses.every(updatedFocuses.contains);
    final completed = statusFocuses.every(completedFocuses.contains);
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? _caseworkSelected : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selected ? _caseworkBlue : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? _caseworkBlue : _caseworkMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : _caseworkInk,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ),
            _FocusStatusButton(
              label: label,
              status: 'updated',
              icon: Icons.update_rounded,
              color: _caseworkUpdated,
              active: updated,
              onPressed: () => onUpdatedToggle(statusFocuses),
            ),
            _FocusStatusButton(
              label: label,
              status: 'completed',
              icon: Icons.check_circle_rounded,
              color: _caseworkCompleted,
              active: completed,
              onPressed: () => onCompletedToggle(statusFocuses),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopClientRail extends StatelessWidget {
  const _DesktopClientRail({
    required this.clientInitialsController,
    required this.workerInitialsController,
    required this.deadlineController,
    required this.contact,
    required this.consent,
    required this.urgency,
    required this.noteType,
    required this.actionCount,
    required this.profileCodes,
    required this.activeProfileCode,
    required this.onProfileChanged,
    required this.onCreateProfile,
    required this.onDeleteProfile,
    required this.onContactChanged,
    required this.onConsentChanged,
    required this.onUrgencyChanged,
    required this.onNoteTypeChanged,
    required this.onTextChanged,
    required this.onClearNote,
  });

  final TextEditingController clientInitialsController;
  final TextEditingController workerInitialsController;
  final TextEditingController deadlineController;
  final String contact;
  final String consent;
  final String urgency;
  final String noteType;
  final int actionCount;
  final List<String> profileCodes;
  final String activeProfileCode;
  final ValueChanged<String> onProfileChanged;
  final VoidCallback onCreateProfile;
  final VoidCallback onDeleteProfile;
  final ValueChanged<String> onContactChanged;
  final ValueChanged<String> onConsentChanged;
  final ValueChanged<String> onUrgencyChanged;
  final ValueChanged<String> onNoteTypeChanged;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onClearNote;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: _caseworkSurface,
        border: Border(right: BorderSide(color: _caseworkLine)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const _RailHeader('Client / whanau'),
          Row(
            children: [
              Expanded(
                child: _DesktopDropdown(
                  label: 'Case file',
                  value: activeProfileCode,
                  values: profileCodes,
                  onChanged: onProfileChanged,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: IconButton.filledTonal(
                  tooltip: 'New case',
                  onPressed: onCreateProfile,
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: IconButton.filledTonal(
                  tooltip: 'Delete case',
                  onPressed: onDeleteProfile,
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            ],
          ),
          _DesktopTextField(
            controller: clientInitialsController,
            label: 'Case code',
            hint: 'CASE-001',
            onChanged: onTextChanged,
          ),
          _DesktopTextField(
            controller: workerInitialsController,
            label: 'Worker',
            hint: 'Your name',
            onChanged: onTextChanged,
          ),
          _DesktopDropdown(
            label: 'Contact Type',
            value: contact,
            values: _contacts,
            onChanged: onContactChanged,
          ),
          _DesktopDropdown(
            label: 'Consent',
            value: consent,
            values: _consents,
            onChanged: onConsentChanged,
          ),
          const Divider(height: 26, color: _caseworkLine),
          const _RailHeader('Risk & urgency'),
          _DesktopDropdown(
            label: 'Risk Level',
            value: urgency,
            values: _urgencyOptions.map((option) => option.value).toList(),
            onChanged: onUrgencyChanged,
          ),
          _DesktopTextField(
            controller: deadlineController,
            label: 'Deadline / Urgency',
            hint: 'e.g. Tonight, 3 days, EH expires Fri',
            onChanged: onTextChanged,
          ),
          const Divider(height: 26, color: _caseworkLine),
          const _RailHeader('Quick note'),
          _DesktopDropdown(
            label: 'Note Style',
            value: noteType,
            values: _noteTypes,
            onChanged: onNoteTypeChanged,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onClearNote,
            icon: const Icon(Icons.brush_outlined, size: 16),
            label: const Text('Clear note only'),
          ),
          const Divider(height: 26, color: _caseworkLine),
          const _RailHeader('Queue'),
          _QueueTile(
            title: '[Current]',
            subtitle: '$actionCount action(s) logged',
          ),
          const _QueueTile(title: '[New]', subtitle: 'No safe place tonight'),
        ],
      ),
    );
  }
}

class _DesktopTextField extends StatelessWidget {
  const _DesktopTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DesktopFieldLabel(label),
          const SizedBox(height: 5),
          TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            decoration: _desktopInputDecoration(hint),
          ),
        ],
      ),
    );
  }
}

class _DesktopDropdown extends StatelessWidget {
  const _DesktopDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            _DesktopFieldLabel(label),
            const SizedBox(height: 5),
          ],
          DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            dropdownColor: _caseworkInkSoft,
            iconEnabledColor: _caseworkMuted,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
            decoration: _desktopInputDecoration(''),
            items: [
              for (final item in values)
                DropdownMenuItem(
                  value: item,
                  child: Text(item, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ],
      ),
    );
  }
}

class _DesktopFieldLabel extends StatelessWidget {
  const _DesktopFieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _caseworkMuted,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

InputDecoration _desktopInputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _caseworkMuted),
    filled: true,
    fillColor: _caseworkInkSoft,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _caseworkLine),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _caseworkLine),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _caseworkAccent, width: 1.5),
    ),
  );
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _caseworkPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _caseworkLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _caseworkInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(color: _caseworkMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DesktopNoteOutput extends StatelessWidget {
  const _DesktopNoteOutput({
    required this.noteType,
    required this.noteFile,
    required this.onNoteTypeChanged,
    required this.onCopy,
    required this.onClear,
  });

  final String noteType;
  final String noteFile;
  final ValueChanged<String> onNoteTypeChanged;
  final VoidCallback onCopy;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      decoration: const BoxDecoration(
        color: _caseworkSurface,
        border: Border(left: BorderSide(color: _caseworkLine)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _caseworkLine)),
            ),
            child: const Text(
              'Note Output',
              style: TextStyle(
                color: _caseworkInk,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _DesktopDropdown(
              label: '',
              value: noteType,
              values: _noteTypes,
              onChanged: onNoteTypeChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: const Text('Copy'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.brush_outlined, size: 16),
                    label: const Text('Clear'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFA23A3A),
                      side: const BorderSide(color: Color(0xFFEAA1A1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: _caseworkPanel,
                border: Border(top: BorderSide(color: _caseworkLine)),
              ),
              padding: const EdgeInsets.all(14),
              child: SingleChildScrollView(
                child: SelectableText(
                  noteFile.isEmpty
                      ? 'Select items to build the note.'
                      : noteFile,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.55,
                    color: _caseworkInk,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopPage extends StatelessWidget {
  const _DesktopPage({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _caseworkInk,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: _caseworkMuted)),
        const SizedBox(height: 18),
        child,
      ],
    );
  }
}

class _DesktopCard extends StatelessWidget {
  const _DesktopCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: _caseworkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _caseworkLine),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 6),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _caseworkSelected,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: _caseworkBlue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _caseworkInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ResponsiveColumns extends StatelessWidget {
  const _ResponsiveColumns({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              Expanded(child: children[index]),
              if (index != children.length - 1) const SizedBox(width: 16),
            ],
          ],
        );
      },
    );
  }
}

class _DesktopStepBar extends StatelessWidget {
  const _DesktopStepBar({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    const labels = [
      '1. Issues',
      '2. Status',
      '3. MSD',
      '4. Referrals',
      '5. Output',
    ];

    return Row(
      children: [
        for (var index = 0; index < labels.length; index++)
          Expanded(
            child: Container(
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: index == current ? _caseworkSelected : _caseworkInkSoft,
                border: Border.all(color: _caseworkLine),
                borderRadius: BorderRadius.horizontal(
                  left: index == 0 ? const Radius.circular(6) : Radius.zero,
                  right: index == labels.length - 1
                      ? const Radius.circular(6)
                      : Radius.zero,
                ),
              ),
              child: Text(
                labels[index],
                style: TextStyle(
                  color: index == current ? Colors.white : _caseworkMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChipPicker extends StatelessWidget {
  const _ChipPicker({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final Set<String> selected;
  final void Function(String item, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options) ...[
          Builder(
            builder: (context) {
              final isSelected = selected.contains(option);

              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (value) => onChanged(option, value),
                visualDensity: VisualDensity.compact,
                backgroundColor: _caseworkInkSoft,
                selectedColor: _caseworkSelected,
                checkmarkColor: _caseworkBlue,
                labelStyle: TextStyle(
                  color: _caseworkInk,
                  fontWeight: FontWeight.w800,
                ),
                side: BorderSide(
                  color: isSelected ? _caseworkBlue : _caseworkLine,
                ),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _WarningStrip extends StatelessWidget {
  const _WarningStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFFC76A)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF8A3F00), height: 1.35),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFF1F638D), width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF125781),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(text, style: const TextStyle(height: 1.35)),
        ],
      ),
    );
  }
}

class _ChecklistLink extends StatelessWidget {
  const _ChecklistLink({required this.selectedCount, required this.onPressed});

  final int selectedCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final message = Text(
          selectedCount == 0
              ? 'No evidence items recorded yet.'
              : '$selectedCount evidence item(s) recorded.',
          style: const TextStyle(
            color: _caseworkMuted,
            fontWeight: FontWeight.w700,
          ),
        );
        final button = OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Open evidence checklist'),
        );

        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [message, const SizedBox(height: 10), button],
          );
        }

        return Row(
          children: [
            Expanded(child: message),
            const SizedBox(width: 12),
            button,
          ],
        );
      },
    );
  }
}

class _ReadinessGrid extends StatelessWidget {
  const _ReadinessGrid({
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  final List<_ReadinessItem> items;
  final Set<String> selected;
  final void Function(_ReadinessItem item, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 880
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final aspectRatio = switch (columns) {
          1 => 2.65,
          2 => 2.15,
          _ => 2.45,
        };

        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: aspectRatio,
          children: [
            for (final item in items)
              _ReadinessTile(
                item: item,
                selected: selected.contains(item.title),
                onChanged: (value) => onChanged(item, value),
              ),
          ],
        );
      },
    );
  }
}

class _ReadinessTile extends StatelessWidget {
  const _ReadinessTile({
    required this.item,
    required this.selected,
    required this.onChanged,
  });

  final _ReadinessItem item;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!selected),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3A2B12) : _caseworkPanel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFFFFB74A) : const Color(0xFFFFDCA0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: selected,
                  onChanged: (value) => onChanged(value ?? false),
                  visualDensity: VisualDensity.compact,
                  activeColor: _caseworkBlue,
                ),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      color: _caseworkInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              item.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _caseworkMuted,
                fontSize: 12,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.tag,
              style: const TextStyle(
                color: Color(0xFFB85800),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LivingPathwayFlow extends StatelessWidget {
  const _LivingPathwayFlow({
    required this.profileCode,
    required this.history,
    required this.openStepCount,
  });

  final String profileCode;
  final List<_RequestHistoryEntry> history;
  final int openStepCount;

  @override
  Widget build(BuildContext context) {
    final latest = history.isEmpty ? null : history.first;

    return _DesktopCard(
      title: 'Identify Scope',
      icon: Icons.account_tree_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LightStatusPill(label: 'Case', value: profileCode),
              _LightStatusPill(label: 'Open steps', value: '$openStepCount'),
              _LightStatusPill(label: 'Requests', value: '${history.length}'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            latest == null
                ? 'Start by selecting the housing position, main trigger, barriers, and likely pathway.'
                : '${latest.status}: ${latest.request}',
            style: const TextStyle(
              color: _caseworkInk,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _PathwayStep extends StatelessWidget {
  const _PathwayStep({
    required this.number,
    required this.title,
    required this.text,
  });

  final String number;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return _DesktopCard(
      title: title,
      icon: Icons.looks_one_outlined,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xFF1F638D),
            child: Text(
              number,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(height: 1.3))),
        ],
      ),
    );
  }
}

class _WordingGrid extends StatelessWidget {
  const _WordingGrid({required this.actions, required this.onSelected});

  final List<_UrgencyAction> actions;
  final ValueChanged<_UrgencyAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final action in actions)
          SizedBox(
            width: 170,
            child: OutlinedButton(
              onPressed: () => onSelected(action),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.all(12),
                foregroundColor: _caseworkInk,
                side: const BorderSide(color: _caseworkLine),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                action.label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionButtonWrap extends StatelessWidget {
  const _ActionButtonWrap({required this.actions, required this.onSelected});

  final List<_QuickLogAction> actions;
  final ValueChanged<_QuickLogAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final action in actions)
          OutlinedButton.icon(
            onPressed: () => onSelected(action),
            icon: Icon(action.icon, size: 16),
            label: Text(action.label),
            style: OutlinedButton.styleFrom(
              foregroundColor: _caseworkInk,
              side: const BorderSide(color: _caseworkLine),
              shape: const StadiumBorder(),
            ),
          ),
      ],
    );
  }
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({
    required this.referral,
    required this.selected,
    required this.selectedProgrammes,
    required this.onToggle,
    required this.onProgrammeToggle,
  });

  final _Referral referral;
  final bool selected;
  final Set<String> selectedProgrammes;
  final VoidCallback onToggle;
  final void Function(String programme, bool selected) onProgrammeToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? _caseworkSelected : _caseworkPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? _caseworkBlue : _caseworkLine),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Color(0x0F000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            referral.category.toUpperCase(),
            style: const TextStyle(
              color: _caseworkMuted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            referral.name,
            style: const TextStyle(
              color: _caseworkInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            referral.fit,
            style: const TextStyle(color: _caseworkInk, height: 1.35),
          ),
          const SizedBox(height: 8),
          Text(
            referral.contact,
            style: const TextStyle(color: _caseworkMuted, fontSize: 12),
          ),
          if (referral.programmes.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ReferralProgrammePicker(
              programmes: referral.programmes,
              selected: selectedProgrammes,
              onChanged: onProgrammeToggle,
            ),
          ],
          if (referral.criteria.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ReferralDetailList(
              title: 'Good fit / criteria',
              values: referral.criteria,
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onToggle,
              child: Text(selected ? 'Remove service' : '+ Add service'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralDetailList extends StatelessWidget {
  const _ReferralDetailList({required this.title, required this.values});

  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _caseworkInk,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final value in values)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: _caseworkInkSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _caseworkLine),
                ),
                child: Text(
                  value,
                  style: const TextStyle(
                    color: _caseworkInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ReferralProgrammePicker extends StatelessWidget {
  const _ReferralProgrammePicker({
    required this.programmes,
    required this.selected,
    required this.onChanged,
  });

  final List<String> programmes;
  final Set<String> selected;
  final void Function(String programme, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select exact programme',
          style: TextStyle(
            color: _caseworkInk,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final programme in programmes)
              FilterChip(
                label: Text(programme),
                selected: selected.contains(programme),
                onSelected: (value) => onChanged(programme, value),
                visualDensity: VisualDensity.compact,
                backgroundColor: _caseworkInkSoft,
                selectedColor: _caseworkSelected,
                checkmarkColor: _caseworkBlue,
                side: BorderSide(
                  color: selected.contains(programme)
                      ? _caseworkBlue
                      : _caseworkLine,
                ),
                labelStyle: const TextStyle(
                  color: _caseworkInk,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ReadinessItem {
  const _ReadinessItem({
    required this.title,
    required this.text,
    required this.tag,
  });

  final String title;
  final String text;
  final String tag;
}

class _PrivacyPanel extends StatelessWidget {
  const _PrivacyPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF102A1C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF31E981)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.privacy_tip_outlined, color: Color(0xFF31E981)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Use initials only in this advocacy file. Record full personal details only in the proper client system or agency form.',
              style: TextStyle(color: Color(0xFFD7FFE9), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldGrid extends StatelessWidget {
  const _FieldGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 2 : 1;
        return GridView.count(
          crossAxisCount: columns,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: columns == 1 ? 4.1 : 4.6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      },
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final ValueChanged<String> onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 1,
      readOnly: readOnly,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

class _DropdownInput extends StatelessWidget {
  const _DropdownInput({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final item in values)
          DropdownMenuItem(value: item, child: Text(item)),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _UrgencyPicker extends StatelessWidget {
  const _UrgencyPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in _urgencyOptions)
          ChoiceChip(
            selected: value == option.value,
            label: Text(option.label),
            avatar: Icon(option.icon, size: 17),
            side: BorderSide(color: option.color),
            selectedColor: option.color.withValues(alpha: 0.25),
            onSelected: (_) => onChanged(option.value),
          ),
      ],
    );
  }
}

class _ChecklistGroup extends StatelessWidget {
  const _ChecklistGroup({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final Set<String> selected;
  final void Function(String item, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final option in options)
          _ChecklistTile(
            label: option,
            selected: selected.contains(option),
            onChanged: (value) => onChanged(option, value),
          ),
      ],
    );
  }
}

class _ScopeGroupCard extends StatelessWidget {
  const _ScopeGroupCard({
    required this.group,
    required this.selected,
    required this.onChanged,
  });

  final _ScopeGroup group;
  final Set<String> selected;
  final void Function(String item, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedCount = group.options
        .where((option) => selected.contains(option))
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF13294D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF34405F)),
                ),
                child: Icon(group.icon, color: const Color(0xFF4F8DF7)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      group.subtitle,
                      style: const TextStyle(
                        color: Color(0xFF8396C7),
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              _LightStatusPill(label: 'Set', value: '$selectedCount'),
            ],
          ),
          const SizedBox(height: 10),
          for (final option in group.options)
            _ChecklistTile(
              label: option,
              selected: selected.contains(option),
              onChanged: (value) => onChanged(option, value),
            ),
        ],
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF13294D) : const Color(0xFF101827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? const Color(0xFF4F8DF7) : const Color(0xFF34405F),
        ),
      ),
      child: CheckboxListTile(
        value: selected,
        onChanged: (value) => onChanged(value ?? false),
        title: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
    );
  }
}

class _ReferralTile extends StatelessWidget {
  const _ReferralTile({
    required this.referral,
    required this.selected,
    required this.selectedProgrammes,
    required this.onToggle,
    required this.onProgrammeToggle,
  });

  final _Referral referral;
  final bool selected;
  final Set<String> selectedProgrammes;
  final VoidCallback onToggle;
  final void Function(String programme, bool selected) onProgrammeToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF13294D) : const Color(0xFF101827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? const Color(0xFF4F8DF7) : const Color(0xFF34405F),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  referral.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: onToggle,
                icon: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                ),
                tooltip: selected ? 'Selected' : 'Add',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            referral.category,
            style: const TextStyle(
              color: Color(0xFF4F8DF7),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            referral.fit,
            style: const TextStyle(color: Color(0xFFCDD7F0), height: 1.35),
          ),
          const SizedBox(height: 6),
          Text(
            referral.contact,
            style: const TextStyle(color: Color(0xFF8396C7), fontSize: 12),
          ),
          if (referral.programmes.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ReferralProgrammePicker(
              programmes: referral.programmes,
              selected: selectedProgrammes,
              onChanged: onProgrammeToggle,
            ),
          ],
          if (referral.criteria.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Good fit: ${referral.criteria.join(', ')}',
              style: const TextStyle(
                color: Color(0xFF9FB2E6),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UrgencyAction {
  const _UrgencyAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.urgency,
    required this.deadline,
    required this.noteType,
    required this.presentingNeeds,
    required this.focus,
    required this.logCategory,
    required this.logText,
    this.situationUnderstanding = const [],
    this.immediateSafety = const [],
    this.documents = const [],
    this.msdCriteria = const [],
    this.msdAdvocacy = const [],
    this.socialHousing = const [],
    this.housingApplications = const [],
    this.accommodationOptions = const [],
    this.probationActions = const [],
    this.referrals = const [],
    this.roadblocks = const [],
    this.socialHousingRating,
    this.probationStatus,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String urgency;
  final String deadline;
  final String noteType;
  final List<String> presentingNeeds;
  final List<String> situationUnderstanding;
  final List<String> immediateSafety;
  final List<String> documents;
  final List<String> msdCriteria;
  final List<String> msdAdvocacy;
  final List<String> socialHousing;
  final List<String> housingApplications;
  final List<String> accommodationOptions;
  final List<String> probationActions;
  final List<String> referrals;
  final List<String> roadblocks;
  final String? socialHousingRating;
  final String? probationStatus;
  final _CaseworkFocus focus;
  final String logCategory;
  final String logText;
}

class _QuickLogAction {
  const _QuickLogAction({
    required this.label,
    required this.icon,
    required this.category,
    required this.action,
  });

  final String label;
  final IconData icon;
  final String category;
  final String action;
}

class _FocusItem {
  const _FocusItem(this.focus, this.label, this.icon);

  final _CaseworkFocus focus;
  final String label;
  final IconData icon;
}

class _ScopeGroup {
  const _ScopeGroup({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.options,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> options;
}

class _UrgencyOption {
  const _UrgencyOption(this.value, this.label, this.icon, this.color);

  final String value;
  final String label;
  final IconData icon;
  final Color color;
}

class _Referral {
  const _Referral(
    this.name,
    this.category,
    this.fit,
    this.contact, {
    this.programmes = const [],
    this.criteria = const [],
  });

  final String name;
  final String category;
  final String fit;
  final String contact;
  final List<String> programmes;
  final List<String> criteria;
}

class _ActionLogEntry {
  const _ActionLogEntry({
    required this.time,
    required this.category,
    required this.action,
  });

  final DateTime time;
  final String category;
  final String action;
}

class _RequestHistoryEntry {
  const _RequestHistoryEntry({
    required this.time,
    required this.category,
    required this.request,
    required this.status,
  });

  final DateTime time;
  final String category;
  final String request;
  final String status;
}

class _CaseProfileRecord {
  const _CaseProfileRecord({
    required this.code,
    required this.updatedAt,
    required this.data,
  });

  final String code;
  final DateTime updatedAt;
  final Map<String, Object?> data;
}

const _housingStatusOptions = [
  'Sleeping rough / car / unsafe',
  'Temporary / couch-surfing',
  'Emergency housing / motel',
  'Asked to leave current place',
  'Private rental at risk',
  'On Public Housing Register',
  'Trying to secure private rental',
  'Housed but unstable',
];

const _evidenceBarrierOptions = [
  'No photo ID',
  'No fixed address',
  'Rent arrears / debt',
  'Poor tenancy history',
  'Criminal / Corrections history',
  'No income / benefit pending',
  'Pets',
  'Children in household',
  'Physical health needs',
  'Mental health / addiction',
  'Language barrier',
  'FV / safety concern',
  'Has existing supports',
  'EH contribution paid',
  'EH contribution issue',
];

const _emergencyHousingOptions = [
  'First grant',
  'Re-grant',
  'Contribution issue',
  'Supplier / motel issue',
  'Declined / warning',
  'Asked to leave motel',
  'CMM EH navigation',
  'CMM transitional check',
];

const _publicHousingOptions = [
  'New application',
  'Update details',
  'Priority review',
  'Transfer / area',
  'Declined',
];

const _financialSupportOptions = [
  'Bond assistance',
  'Rent in advance',
  'Rent arrears',
  'Accommodation Supplement',
  'Hardship / STAP',
  'Moving costs',
];

const _cmmPathwayOptions = [
  'EH social support/navigation',
  'Housing advocacy/navigation',
  'Transitional housing',
  'Rapid rehousing',
  'Sustaining tenancies',
  'Housing First Blenheim',
  'Social housing',
  'Affordable rentals',
];

const _referralFilterOptions = [
  'Tonight / accommodation',
  'CMM housing',
  'Probation / bail',
  '501 returnee',
  'FV / safety',
  'Tenancy legal',
  'Kai / essentials',
  'Mental health',
  'Addiction',
  'Youth / whanau',
  'Disability / older',
  'Migrant / language',
];

const _socialSupportOptions = [
  'Kai / meals',
  'Whanau Ora',
  'Youth',
  'Iwi / kaupapa Maori',
  'Kaumatua / disability',
  'Housing support',
  'Education / mahi',
  'Mental health',
  'Budgeting',
  'Legal / tenancy',
];

const _referralFilterKeywords = <String, List<String>>{
  'Tonight / accommodation': [
    'emergency housing',
    'accommodation',
    'refuge',
    'homeless',
    'housing',
  ],
  'CMM housing': ['cmm', 'transitional', 'rapid rehousing', 'housing first'],
  'Probation / bail': ['corrections', 'probation', 'bail', 'returnee'],
  '501 returnee': ['501', 'returnee', 'corrections', 'transition'],
  'FV / safety': [
    'family violence',
    'sexual harm',
    'sexual violence',
    'safety',
    'victim',
    'refuge',
  ],
  'Tenancy legal': ['tenancy', 'legal', 'rights', 'community law', 'cab'],
  'Kai / essentials': [
    'food',
    'kai',
    'meal',
    'hardship',
    'essentials',
    'food parcel',
  ],
  'Mental health': ['mental health', 'mental-health', 'camhs', 'psychiatric'],
  'Addiction': ['addiction', 'drug', 'alcohol', 'detox', 'opioid'],
  'Youth / whanau': ['youth', 'child', 'whanau', 'parent', 'tamariki', 'pepi'],
  'Disability / older': [
    'disability',
    'older',
    'dementia',
    'mobility',
    'palliative',
    'over-65',
  ],
  'Migrant / language': [
    'migrant',
    'refugee',
    'settlement',
    'language',
    'translation',
    'esol',
  ],
  'Kai / meals': ['food', 'kai', 'meal', 'food parcel', 'kitchen', 'cafe'],
  'Whanau Ora': ['whanau ora', 'whanau', 'hauora'],
  'Youth': ['youth', 'child', 'tamariki', 'adolescent', 'young'],
  'Iwi / kaupapa Maori': [
    'maori',
    'kaupapa',
    'iwi',
    'rangitane',
    'ngati rarua',
  ],
  'Kaumatua / disability': [
    'older',
    'kaumatua',
    'disability',
    'dementia',
    'mobility',
  ],
  'Housing support': [
    'housing',
    'accommodation',
    'tenancy',
    'homeless',
    'rental',
  ],
  'Education / mahi': [
    'education',
    'employment',
    'literacy',
    'work readiness',
    'jobseeker',
  ],
  'Budgeting': ['budget', 'financial', 'debt', 'arrears', 'hardship'],
  'Legal / tenancy': ['legal', 'tenancy', 'rights', 'law', 'cab'],
};

const _commonObjections = [
  'I only want private rental, not social housing',
  'I will not live in that area',
  'I cannot live near that person / perpetrator',
  'I do not want emergency housing',
  'MSD already declined me',
  'I cannot pay the contribution',
  'I have no ID or documents',
  'I cannot attend the appointment',
];

const _ehReadinessItems = [
  _ReadinessItem(
    title: 'no safe place tonight / next 7 nights confirmed',
    text:
        'Record where client slept last night, where they can safely sleep tonight, and what happens if MSD does not grant tonight.',
    tag: 'Immediate need',
  ),
  _ReadinessItem(
    title: 'cannot safely stay where they are',
    text:
        'Document why the current place has ended or is unsafe/unreasonable: asked to leave, violence, overcrowding, eviction, motel exit, couch-surfing ended, health risk.',
    tag: 'Current place',
  ),
  _ReadinessItem(
    title: 'no reasonable whanau/friend/network option available',
    text:
        'Record who was asked, why it is unavailable or unsafe, and whether any option is only short-term or creates risk.',
    tag: 'Alternatives',
  ),
  _ReadinessItem(
    title: 'client eligibility and identity checked',
    text:
        'Check NZ residence/benefit/ordinary residence situation, photo ID or alternative ID pathway, DOB and household details.',
    tag: 'Eligibility / ID',
  ),
  _ReadinessItem(
    title: 'income, benefit and bank details confirmed',
    text:
        'Check main benefit or wages, partner income, bank account, payment card/access to funds, and whether benefit/address needs updating.',
    tag: 'Income',
  ),
  _ReadinessItem(
    title: 'household needs and risks documented',
    text:
        'List adults, tamariki, pregnancy, disability, pets, vehicle, phone access, medication, safety exclusions and accessibility needs.',
    tag: 'Household',
  ),
  _ReadinessItem(
    title: 'available money and EH contribution explained',
    text:
        'Check current funds and explain EH contribution expectations after 7 nights; record hardship if contribution is not affordable.',
    tag: 'Contribution',
  ),
  _ReadinessItem(
    title: 'transitional housing / CMM pathway checked with MSD',
    text:
        'Ask MSD whether transitional housing, CMM pathway or other supported option should be considered before or alongside EH.',
    tag: 'Alternative pathway',
  ),
  _ReadinessItem(
    title: 'suitable accommodation type checked',
    text:
        'Check if motel, boarding house, backpackers or holiday park is suitable for household, safety, disability, tamariki and Corrections conditions.',
    tag: 'Accommodation fit',
  ),
  _ReadinessItem(
    title: 'probation / bail / EM address restrictions checked',
    text:
        'Before placing or moving, check PO/Court/EM conditions, approved address requirements, curfew, exclusion zones and travel limits.',
    tag: 'Corrections / MOJ',
  ),
  _ReadinessItem(
    title: 'safety evidence gathered where relevant',
    text:
        'Police event, Women\'s Refuge/FV service, protection order, safety plan, OT/school/health worker or support agency evidence.',
    tag: 'Safety',
  ),
  _ReadinessItem(
    title: 'housing search / re-grant activity log ready',
    text:
        'For re-grants, have contacts, applications, viewings, declines, no responses, CMM/MSD actions and follow-up tasks recorded.',
    tag: 'Re-grant evidence',
  ),
  _ReadinessItem(
    title: 'previous EH warnings / decline / exit reasons checked',
    text:
        'Ask what MSD needs resolved: contribution, missed appointment, supplier incident, responsibilities, conduct, housing activity or other decline reason.',
    tag: 'Warnings',
  ),
  _ReadinessItem(
    title: 'client can attend MSD and be contactable',
    text:
        'Confirm phone, transport, appointment time, support-worker attendance, safe contact method and what the client must say/do next.',
    tag: 'Appointment',
  ),
];

const _diaryQuickActions = [
  _QuickLogAction(
    label: 'GP / health contact',
    icon: Icons.local_hospital_outlined,
    category: 'Health',
    action: 'GP/medical evidence and support need recorded',
  ),
  _QuickLogAction(
    label: 'Mental health contact',
    icon: Icons.psychology_outlined,
    category: 'Mental health',
    action: 'Mental health/addiction service engagement recorded',
  ),
  _QuickLogAction(
    label: 'Iwi provider contact',
    icon: Icons.groups_outlined,
    category: 'Kaupapa Maori',
    action: 'Iwi/kaupapa Maori provider engagement recorded',
  ),
  _QuickLogAction(
    label: 'Budgeting contact',
    icon: Icons.account_balance_wallet_outlined,
    category: 'Budgeting',
    action: 'Budgeting/financial mentoring engagement recorded',
  ),
  _QuickLogAction(
    label: 'Legal/CAB contact',
    icon: Icons.balance_outlined,
    category: 'Legal',
    action: 'Legal/CAB/Community Law engagement recorded',
  ),
  _QuickLogAction(
    label: 'Housing search evidence',
    icon: Icons.search_outlined,
    category: 'Housing search',
    action: 'Housing search activity added for EH re-grant evidence',
  ),
  _QuickLogAction(
    label: 'Client check-in',
    icon: Icons.sms_outlined,
    category: 'Client contact',
    action: 'Client check-in completed and next actions confirmed',
  ),
];

const _wordingActions = [
  _UrgencyAction(
    label: 'No safe place tonight',
    icon: Icons.night_shelter_outlined,
    color: Color(0xFFFF5A5F),
    urgency: 'critical',
    deadline: 'Tonight / before close of business',
    noteType: 'MSD call support note',
    presentingNeeds: ['No safe place tonight'],
    situationUnderstanding: [
      'No safe place tonight',
      'MSD emergency housing assessment',
    ],
    msdCriteria: [
      'No safe or adequate accommodation available now',
      'No realistic whanau/friends/private option available tonight',
    ],
    focus: _CaseworkFocus.msd,
    logCategory: 'Wording',
    logText: 'No-safe-place wording added',
  ),
  _UrgencyAction(
    label: 'Transitional housing request',
    icon: Icons.route_outlined,
    color: Color(0xFF31E981),
    urgency: 'high',
    deadline: 'Urgent transitional pathway',
    noteType: 'CMM / MSD handover note',
    presentingNeeds: ['Transitional housing needed'],
    msdAdvocacy: ['MSD asked to check transitional housing options'],
    referrals: ['CMM Te Tau Ihu Blenheim'],
    focus: _CaseworkFocus.housing,
    logCategory: 'Wording',
    logText: 'Transitional housing wording added',
  ),
  _UrgencyAction(
    label: 'EH re-grant risk',
    icon: Icons.warning_amber_outlined,
    color: Color(0xFFFFB020),
    urgency: 'high',
    deadline: 'Before next re-grant',
    noteType: 'MSD call support note',
    presentingNeeds: ['Emergency housing re-grant'],
    msdAdvocacy: ['EH re-grant evidence prepared'],
    msdCriteria: ['Housing search / alternative options evidence ready'],
    focus: _CaseworkFocus.msd,
    logCategory: 'Wording',
    logText: 'EH re-grant wording added',
  ),
  _UrgencyAction(
    label: 'Tenancy at risk',
    icon: Icons.house_siding_outlined,
    color: Color(0xFF4F8DF7),
    urgency: 'medium',
    deadline: 'Before tenancy deadline',
    noteType: 'Housing application support note',
    presentingNeeds: ['Rent arrears / tenancy risk'],
    housingApplications: ['Sustaining tenancies/prevention pathway considered'],
    referrals: ['Community Law Marlborough'],
    focus: _CaseworkFocus.referrals,
    logCategory: 'Wording',
    logText: 'Tenancy-risk wording added',
  ),
  _UrgencyAction(
    label: 'Chronic homelessness',
    icon: Icons.home_work_outlined,
    color: Color(0xFFB56CFF),
    urgency: 'high',
    deadline: 'Housing First pathway',
    noteType: 'CMM / MSD handover note',
    presentingNeeds: ['Transitional housing needed'],
    housingApplications: ['Housing First suitability considered'],
    referrals: ['Housing First Blenheim', 'CMM Te Tau Ihu Blenheim'],
    focus: _CaseworkFocus.housing,
    logCategory: 'Wording',
    logText: 'Chronic homelessness wording added',
  ),
  _UrgencyAction(
    label: 'Motel/supplier issue',
    icon: Icons.hotel_outlined,
    color: Color(0xFFFFB020),
    urgency: 'high',
    deadline: 'Before supplier exit',
    noteType: 'MSD call support note',
    presentingNeeds: ['Motel / supplier issue'],
    msdAdvocacy: ['Supplier safety/suitability concern raised'],
    accommodationOptions: ['Motel/supplier vacancy and suitability checked'],
    focus: _CaseworkFocus.msd,
    logCategory: 'Wording',
    logText: 'Motel/supplier wording added',
  ),
];

const _contacts = [
  'Walk-in',
  'Phone',
  'Home visit',
  'Email',
  'Outreach',
  'Referral in',
];

const _consents = [
  'Verbal consent given',
  'Written consent given',
  'Consent pending',
  'Consent declined',
];

const _noteTypes = [
  'Peer support housing note',
  'MSD call support note',
  'CMM / MSD handover note',
  'Housing application support note',
  'Referral and next-steps note',
];

const _focusItems = [
  _FocusItem(_CaseworkFocus.walkIn, 'Walk-in', Icons.front_hand_outlined),
  _FocusItem(
    _CaseworkFocus.situation,
    'Situation',
    Icons.psychology_alt_outlined,
  ),
  _FocusItem(_CaseworkFocus.safety, 'Safety', Icons.health_and_safety_outlined),
  _FocusItem(_CaseworkFocus.documents, 'Docs', Icons.badge_outlined),
  _FocusItem(_CaseworkFocus.msd, 'MSD', Icons.fact_check_outlined),
  _FocusItem(_CaseworkFocus.housing, 'Rating', Icons.home_work_outlined),
  _FocusItem(_CaseworkFocus.accommodation, 'Accom', Icons.bed_outlined),
  _FocusItem(_CaseworkFocus.probation, 'Probation', Icons.gavel_outlined),
  _FocusItem(
    _CaseworkFocus.referrals,
    'Referrals',
    Icons.support_agent_outlined,
  ),
  _FocusItem(_CaseworkFocus.file, 'File', Icons.description_outlined),
];

const _quickLogActions = [
  _QuickLogAction(
    label: 'MSD called',
    icon: Icons.phone_in_talk_outlined,
    category: 'MSD',
    action: 'MSD contacted; outcome/follow-up to be checked in file',
  ),
  _QuickLogAction(
    label: 'Doc received',
    icon: Icons.attach_file_outlined,
    category: 'Documents',
    action: 'Document/evidence received or sighted',
  ),
  _QuickLogAction(
    label: 'Referral sent',
    icon: Icons.outgoing_mail,
    category: 'Referral',
    action: 'Referral/support request sent or discussed',
  ),
  _QuickLogAction(
    label: 'Accom checked',
    icon: Icons.bed_outlined,
    category: 'Accommodation',
    action: 'Accommodation option checked for availability/suitability',
  ),
  _QuickLogAction(
    label: 'Client updated',
    icon: Icons.sms_outlined,
    category: 'Client update',
    action: 'Client updated with current plan and next contact',
  ),
  _QuickLogAction(
    label: 'Follow-up set',
    icon: Icons.event_available_outlined,
    category: 'Follow-up',
    action: 'Follow-up time/date set before closing contact',
  ),
];

const _socialHousingRatings = [
  'Not checked',
  'Not on register',
  'Application needed',
  'On register - rating unknown',
  'Priority A / urgent need',
  'Priority B / serious need',
  'Rating review needed',
];

const _probationStatuses = [
  'Not applicable',
  'Check required',
  'Probation involved',
  'Bail address needed',
  'Release address needed',
  'Corrections approval pending',
];

const _urgencyOptions = [
  _UrgencyOption(
    'critical',
    'Critical',
    Icons.error_outline_rounded,
    Color(0xFFFF5A5F),
  ),
  _UrgencyOption(
    'high',
    'High',
    Icons.priority_high_rounded,
    Color(0xFFFFB020),
  ),
  _UrgencyOption(
    'medium',
    'Medium',
    Icons.remove_circle_outline_rounded,
    Color(0xFF4F8DF7),
  ),
  _UrgencyOption(
    'low',
    'Low',
    Icons.check_circle_outline_rounded,
    Color(0xFF31E981),
  ),
];

const _presentingNeedOptions = [
  'No safe place tonight',
  'Asked to leave / cannot return',
  'Emergency housing assessment',
  'Emergency housing re-grant',
  'Transitional housing needed',
  'Motel / supplier issue',
  'Family violence / personal safety',
  'Children or dependants affected',
  'Health, access, or medication support need',
  'Probation / bail address issue',
  'Rent arrears / tenancy risk',
  'Kai / essentials / hardship',
];

const _situationScopeGroups = [
  _ScopeGroup(
    title: 'Housing Position',
    subtitle: 'Identify where the person is tonight and what is changing.',
    icon: Icons.home_outlined,
    options: [
      'No safe place tonight',
      'Can stay one night only',
      'Couch-surfing / unstable temporary stay',
      'In emergency housing / motel now',
      'Leaving custody, hospital, or another service',
      'Tenancy at risk but still housed',
    ],
  ),
  _ScopeGroup(
    title: 'Main Trigger',
    subtitle: 'Name the pressure point so the right pathway is used.',
    icon: Icons.crisis_alert_outlined,
    options: [
      'Asked to leave or cannot return',
      'EH re-grant or placement ending',
      'Family violence or personal safety concern',
      'Probation / bail / release address issue',
      'Rent arrears, eviction notice, or tenancy breakdown',
      'Income or payment gap affecting accommodation',
    ],
  ),
  _ScopeGroup(
    title: 'Who Is Affected',
    subtitle: 'Capture practical responsibilities without over-noting.',
    icon: Icons.groups_2_outlined,
    options: [
      'Single adult',
      'Couple or whanau group',
      'Children or dependants involved',
      'Pets or belongings affecting options',
      'Needs accessible accommodation or transport support',
      'Whanau / natural support available with consent',
    ],
  ),
  _ScopeGroup(
    title: 'Access Barriers',
    subtitle: 'Spot roadblocks before MSD, providers, or landlords ask.',
    icon: Icons.block_outlined,
    options: [
      'No photo ID or replacement needed',
      'No phone, data, email, or charging access',
      'No transport to appointment or accommodation',
      'No income evidence or bank access ready',
      'Past debt, ban, trespass, or supplier concern',
      'Needs support to explain situation to agency',
    ],
  ),
  _ScopeGroup(
    title: 'Likely Pathway',
    subtitle: 'Choose the working route before making calls.',
    icon: Icons.route_outlined,
    options: [
      'MSD emergency housing assessment',
      'Backpacker / hostel / short stay option',
      'CMM housing advocacy or navigation',
      'Transitional housing referral pathway',
      'Public housing register or rating review',
      'Private rental / bond / rent-in-advance support',
      'Probation or bail address coordination',
    ],
  ),
];

const _immediateSafetyOptions = [
  'Safe place for tonight confirmed or escalated',
  'Immediate danger / family violence screened',
  'Children, dependants, pets, and transport checked',
  'Medication, mobility, and access needs checked',
  'Phone battery/contact method checked',
  'Client knows next appointment/call time',
  'Emergency escalation option explained if risk changes',
];

const _roadblockOptions = [
  'Consent wording ready before calling agency',
  'Client initials only used in this working note',
  'Agency contact person/name recorded in action log',
  'Follow-up time/date set before ending contact',
  'Decline/reason requested if agency cannot assist',
  'Alternative pathway selected before closing the walk-in',
  'Supervisor/escalation needed if no safe option remains',
];

const _documentOptions = [
  'Photo ID checked or replacement pathway started',
  'Birth certificate/passport/driver licence status checked',
  'IRD number / client number available or recovery started',
  'Benefit/income evidence available',
  'Bank statement or account evidence available',
  'Current address / last stable address evidence checked',
  'Tenancy notice, eviction, or supplier issue evidence checked',
  'Housing search evidence gathered',
  'Wellbeing, access, or safety evidence considered',
  'Phone/email access for applications checked',
];

const _msdCriteriaOptions = [
  'No safe or adequate accommodation available now',
  'No realistic whanau/friends/private option available tonight',
  'Unable to pay for suitable temporary accommodation without assistance',
  'MSD identity/client number pathway checked',
  'Income and cash-on-hand checked for MSD assessment',
  'Reason current accommodation ended recorded',
  'EH contribution explained if placement continues',
  'Housing search / alternative options evidence ready',
  'Safety, access, children, or transport factors recorded',
  'MSD decline reason requested if emergency housing not granted',
];

const _msdAdvocacyOptions = [
  'MSD emergency housing assessment requested',
  'MSD asked to check transitional housing options',
  'CMM EH social support/navigation requested',
  'CMM housing advocacy/navigation pathway requested',
  'EH re-grant evidence prepared',
  'Emergency housing contribution issue checked',
  'Hardship, bond, rent advance, and arrears support checked',
  'Public housing register status checked',
  'Supplier safety/suitability concern raised',
  'MSD outcome, person spoken to, and next contact logged',
];

const _housingApplicationOptions = [
  'Public housing application started/updated',
  'Private rental search list started',
  'References/support letter need checked',
  'Viewing/application barriers checked',
  'Budget/rent affordability checked',
  'Bond/rent in advance pathway checked',
  'Transitional housing referral need checked',
  'Housing First suitability considered',
  'Sustaining tenancies/prevention pathway considered',
];

const _socialHousingOptions = [
  'Public housing register status checked',
  'Current rating/priority asked for and recorded',
  'Rating review requested if needs have changed',
  'Health/access evidence linked to rating',
  'Family violence/safety evidence linked to rating',
  'Children/dependants overcrowding evidence linked to rating',
  'Homelessness/EH history linked to rating',
  'Support letter or advocacy summary needed',
  'Preferred areas and accessibility needs recorded',
];

const _accommodationOptions = [
  'Emergency housing through MSD checked first',
  'Backpacker/hostel option checked for tonight',
  'Motel/supplier vacancy and suitability checked',
  'Whanau/friends option checked and reason unavailable recorded',
  'Women\'s Refuge/safety accommodation checked if relevant',
  'Medical/accessibility suitability checked',
  'Transport to accommodation checked',
  'Payment pathway checked: MSD, hardship, bond, rent advance, client funds',
  'Rules/ID/check-in time confirmed before sending client',
  'Plan for next business day made before placement ends',
];

const _probationActionOptions = [
  'Probation officer / Corrections contact identified',
  'Consent to speak with Corrections recorded',
  'Bail/release address requirement clarified',
  'Address suitability requirements checked',
  'Emergency housing/backpacker suitability for bail checked',
  'Curfew, reporting, exclusion, or safety conditions checked',
  'Written confirmation requested if address declined',
  'Alternative address pathway identified',
  'Corrections/MSD/CMM next contact time recorded',
];

const _minimumSafetyChecks = [
  'Safe place for tonight confirmed or escalated',
  'Immediate danger / family violence screened',
  'Client knows next appointment/call time',
];

const _minimumMsdCriteriaChecks = [
  'No safe or adequate accommodation available now',
  'No realistic whanau/friends/private option available tonight',
  'Unable to pay for suitable temporary accommodation without assistance',
];

const _minimumDocumentChecks = [
  'Photo ID checked or replacement pathway started',
  'Benefit/income evidence available',
  'Housing search evidence gathered',
];

const _minimumMsdChecks = [
  'MSD emergency housing assessment requested',
  'MSD asked to check transitional housing options',
  'MSD outcome, person spoken to, and next contact logged',
];

const _referralOptions = [
  _Referral(
    'Work and Income Blenheim',
    'Emergency + MSD housing',
    'Benefits, food grants, accommodation support, public housing applications, employment help, income support, and phone interpreters.',
    '0800 559 009; Service Express 0800 33 30 30; Riverview House, 11 Alfred Street, Blenheim',
    programmes: [
      'Emergency Housing',
      'Public housing assessment',
      'Accommodation Supplement',
      'Food grants',
      'Bond Grant',
      'Rent in advance',
      'Moving costs',
      'Tenancy costs',
      'Employment support',
      'Hardship / urgent costs',
    ],
    criteria: [
      'No safe place tonight or next 7 nights',
      'Identity and income checked',
      'Money available checked',
      'Whanau/private options explored',
      'Housing search or re-grant evidence ready',
    ],
  ),
  _Referral(
    'CMM Te Tau Ihu Blenheim',
    'Emergency + transitional housing',
    'Housing advocacy, emergency-housing navigation, transitional pathways, and tenancy support.',
    '69 Scott Street, Blenheim; 0800 432 536; referralscmmblenheim@mmsi.org.nz',
    programmes: [
      'EH social support/navigation',
      'Housing advocacy/navigation',
      'Transitional housing',
      'Rapid rehousing',
      'Sustaining tenancies',
      'Housing First Blenheim',
      'Social housing navigation',
    ],
    criteria: [
      'Homeless or housing unstable',
      'MSD/EH pathway involved or likely',
      'Barriers to independent housing',
      'Consent to share with CMM/MSD',
      'Ongoing housing plan needed',
    ],
  ),
  _Referral(
    'Housing First Blenheim',
    'Chronic homelessness',
    'Housing First pathway for long-term homelessness and multiple complex needs.',
    'admin@housingfirstblenheim.co.nz',
    programmes: [
      'Housing First',
      'Intensive housing navigation',
      'Sustaining tenancy support',
      'Wraparound support',
    ],
    criteria: [
      'Chronic or recurring homelessness',
      'High or complex support needs',
      'Needs long-term tenancy support',
      'Other short-term pathways not enough',
    ],
  ),
  _Referral(
    'Marlborough Sustainable Housing Trust',
    'Affordable housing',
    'Local community housing provider for affordable rental housing and shared ownership pathways.',
    'marlboroughhousingtrust@gmail.com; no standard public walk-in office published',
    programmes: [
      'Affordable rental housing',
      'Shared ownership',
      'Community housing',
      'Accessible / lifetime design housing',
    ],
    criteria: [
      'Future vacancy interest may route via CMM',
      'No general walk-in intake published',
      'Longer-term housing pathway rather than same-day crisis',
      'Client can wait for vacancy / registration pathway',
    ],
  ),
  _Referral(
    'Marlborough Women\'s Refuge / Sexual Assault Resource Centre',
    'Family violence / sexual harm',
    'Safety planning, refuge or safe accommodation, advocacy, and sexual-violence support.',
    '03 577 9939; use 111 if there is immediate danger',
    programmes: [
      'Refuge / safe accommodation',
      'Family violence support',
      'Safety planning',
      'Sexual assault support',
      'Advocacy and referrals',
    ],
    criteria: [
      'Family violence or sexual harm risk',
      'Safe contact method checked',
      'Consent and immediate risk assessed',
      'Escalate to 111 if immediate danger',
    ],
  ),
  _Referral(
    'Police / Emergency Services',
    'Immediate safety',
    'Emergency response where there is immediate risk, family violence, crime, or welfare danger.',
    '111 for immediate danger; Blenheim Police 03 578 5279',
    programmes: [
      'Emergency response',
      'Family violence response',
      'Welfare / safety response',
      'Protection order breach response',
    ],
    criteria: [
      'Immediate danger or serious risk',
      'Violence, threats, or unsafe location',
      'Crime or welfare emergency',
      'Worker safety concern',
    ],
  ),
  _Referral(
    'Community Law Marlborough',
    'Tenancy / legal',
    'Legal information, advice, education, and assistance for tenancy, benefit, debt, and rights issues.',
    '14 Market Street, Blenheim; 03 577 9919 or 0800 266 529',
    programmes: [
      'Legal advice',
      'Legal education',
      'Tenancy rights',
      'Benefit / debt rights',
      'Family / civil legal help',
    ],
    criteria: [
      'Legal issue affects housing, income, or safety',
      'Letters/notices/documents available',
      'Appointment or referral may be needed',
      'Urgent court matter flagged early',
    ],
  ),
  _Referral(
    'Citizens Advice Bureau Marlborough',
    'Advice / navigation',
    'Free, confidential information and practical navigation for rights, forms, services, and referrals.',
    '25 Alfred Street, Blenheim; 03 578 4272',
    programmes: [
      'Information and support',
      'Forms / navigation',
      'Rights and referrals',
      'Tenancy / consumer / benefit guidance',
    ],
    criteria: [
      'Client needs neutral information',
      'Issue not ready for specialist legal advice',
      'Bring letters or forms if possible',
      'Good first-stop referral',
    ],
  ),
  _Referral(
    'Te Piki Oranga',
    'Maori health / Whanau Ora',
    'Kaupapa Maori health and wellness, mental-health and addiction support, Whanau Ora, screening, outreach, and mobile services.',
    '03 578 5750 or 0800 672 642; admin.wairau@tpo.org.nz; 22 Queen Street, Blenheim',
    programmes: [
      'Whanau Ora',
      'Hauora navigation',
      'Mental-health support',
      'Addiction support',
      'Screening / outreach',
      'Mobile services',
    ],
    criteria: [
      'Self / whanau referral supported',
      'Online or printed referral form',
      'Community outreach available',
      'Whanau-centred Maori service wanted',
    ],
  ),
  _Referral(
    'Maataa Waka Ki Te Tau Ihu Trust',
    'Kaupapa Maori / youth / whanau',
    'Kaupapa Maori social services, youth support, whanau support, and self-referral pathways.',
    '56 Main Street, Blenheim; 03 577 9256',
    programmes: [
      'Youth Social Service',
      'Hapai Pukuriri',
      'E Tipu e Rea',
      'Fresh Start',
      'Tiramarama Mai',
      'Whanau support',
    ],
    criteria: [
      'Self-referral or any referral source',
      'Youth or whanau support need',
      'Some youth programmes have age bands',
      'Kaupapa Maori approach appropriate',
    ],
  ),
  _Referral(
    'Barnardos Blenheim',
    'Youth / family / counselling',
    'Counselling and social work support for young people and families.',
    'Health Hub, 22 Queen Street, Blenheim; 03 578 6491',
    programmes: [
      'Youth counselling',
      'Family social work',
      'Parent / family support',
      'Child and youth wellbeing',
    ],
    criteria: [
      'Young person or family support need',
      'Self-referral possible',
      'Not an emergency crisis service',
      'Consent and safe contact checked',
    ],
  ),
  _Referral(
    'Birthright Marlborough',
    'One-parent families',
    'Support, advocacy, parenting, life skills, activities, and counselling for one-parent families.',
    '0800 457 146',
    programmes: [
      'Home-based support',
      'Parent education',
      'Life skills',
      'Advocacy',
      'Holiday camps / activities',
      'Counselling',
    ],
    criteria: [
      'One-parent family',
      'Parenting or family support need',
      'Children in household',
      'Local availability checked',
    ],
  ),
  _Referral(
    'Open Home Foundation Marlborough',
    'Children / families / mentoring',
    'Social work, respite, foster care, and mentoring support for children, youth, and families.',
    '03 578 0807',
    programmes: [
      'Family social work',
      'Respite care',
      'Foster care',
      'Family mentoring',
      'Youth mentoring',
    ],
    criteria: [
      'Child or family support/risk need',
      'Mentoring, care, or respite need',
      'Referral and assessment likely',
      'Safety concerns recorded',
    ],
  ),
  _Referral(
    'Marlborough Youth Trust',
    'Youth',
    'Youth development, advocacy, employability, groups, events, and MySpace youth centre.',
    '03 579 3143; 021 161 4671; info@myt.org.nz; 18 Kinross Street, Blenheim',
    programmes: [
      'Youth development',
      'Youth advocacy',
      'Youth employability',
      'Licence-to-work',
      'Young parents group',
      'Queer group',
      'Youth in Emergency Services',
      'MySpace youth centre',
    ],
    criteria: [
      'Young person needs support or connection',
      'Community-entry service for youth',
      'Referral can come from GP, OT, MSD, or others',
      'Koha/donation model',
    ],
  ),
  _Referral(
    'Presbyterian Support Upper South Island / Family Works',
    'Family / youth / older people',
    'Family, youth, counselling, social work, and older-person support pathways.',
    'Check current Marlborough listing before referral',
    programmes: [
      'Family Works',
      'Counselling',
      'Social work',
      'Parenting / family support',
      'Older people services',
    ],
    criteria: [
      'Family or social support need',
      'Programme availability checked',
      'Consent to referral',
      'Risk or urgency noted',
    ],
  ),
  _Referral(
    'Crossroads / John\'s Kitchen',
    'Kai / practical support',
    'Drop-in, meals, bread, koha cafe, social connection, and practical support.',
    '2 Redwood Street, Blenheim; 03 578 5395',
    programmes: [
      'Drop-in centre',
      'John\'s Kitchen',
      'Free bread',
      'Koha cafe / meals',
      'Social connection',
    ],
    criteria: [
      'Immediate kai or basic support',
      'Drop-in hours checked',
      'Client can safely attend',
      'Good same-day practical support',
    ],
  ),
  _Referral(
    'Budgeting / Financial Mentor',
    'Debt / contribution',
    'Budgeting, debt, EH contribution, arrears, payment plans, and hardship evidence.',
    'Use Family Services Directory / local provider contact',
    programmes: [
      'Financial mentoring',
      'Debt plan',
      'Hardship support evidence',
      'EH contribution planning',
      'Rent arrears plan',
    ],
    criteria: [
      'Debt, arrears, or contribution issue',
      'Income and expenses available',
      'Client agrees to budgeting support',
      'Appointment date recorded',
    ],
  ),
  _Referral(
    'Community Food / Emergency Relief Providers',
    'Kai / essentials / hardship',
    'Food parcels, emergency relief, clothing, household goods, and practical crisis support.',
    'Use Family Services Directory / local provider contact',
    programmes: [
      'Food parcels',
      'Emergency relief',
      'Clothing / household goods',
      'Hardship advocacy',
      'Community connectors',
    ],
    criteria: [
      'Immediate hardship or basic needs',
      'Provider hours and stock checked',
      'Referral criteria vary by provider',
      'Urgency and household size recorded',
    ],
  ),
  _Referral(
    'Marlborough Migrant Centre / Newcomers Network',
    'Migrant / settlement',
    'Settlement support, local navigation, newcomer connection, and community support.',
    '21 Henry Street, Blenheim; 03 579 6410; 022 657 9018',
    programmes: [
      'Newcomers Network',
      'Settlement support',
      'Community connection',
      'Local navigation',
      'Migrant support',
    ],
    criteria: [
      'New to Marlborough or New Zealand',
      'Migrant or settlement support need',
      'Language/cultural navigation need',
      'Safe contact details checked',
    ],
  ),
  _Referral(
    'Multicultural Centre Marlborough',
    'Migrant / multicultural',
    'Information and support for immigrants, newcomers network, multicultural events, and translation help in many languages.',
    '03 579 6410 or 027 210 6386; Marlborough House, corner George Street and 21 Henry Street, Blenheim',
    programmes: [
      'Immigrant support',
      'Newcomers network',
      'Multicultural events',
      'Translation help',
      'Community language support',
    ],
    criteria: [
      'Migrant, newcomer, or settlement need',
      'Appointment can be made',
      'Office coordinator not always in office',
      'Language/cultural support needed',
    ],
  ),
  _Referral(
    'Marlborough Pacific Trust',
    'Pacific people',
    'Pacific-led health, social and youth support, navigation/kaiawhina support, and community connection.',
    '0800 846 252 or 03 927 3049; office@marlboroughpacifictrust.co.nz; 18 Pitchill Street, Blenheim',
    programmes: [
      'Pacific health support',
      'Pacific social support',
      'Youth support',
      'Navigation / kaiawhina support',
      'Community connection',
    ],
    criteria: [
      'Pacific support need',
      'Contact us / walk in pathway published',
      'No specific referral barrier published',
      'Cultural support wanted',
    ],
  ),
  _Referral(
    'Age Concern Marlborough',
    'Older people',
    'Advice, advocacy, visiting service, social activities, education, resources, Total Mobility assessments, and in-home support referrals.',
    '03 579 3457 or 0800 65 2 105; office@ageconcernmarlb.org.nz; Room 1, 25 Alfred Street, Blenheim',
    programmes: [
      'Older people advice',
      'Advocacy',
      'Visiting service',
      'Social activities',
      'Education / resources',
      'Total Mobility assessments',
      'In-home support referrals',
    ],
    criteria: [
      'Older person or carer support need',
      'Public-facing community centre office hours',
      'Isolation, mobility, or practical support concern',
      'Urgent danger escalated separately',
    ],
  ),
  _Referral(
    'Marlborough PHO / Primary Mental Health',
    'Mental health / addiction',
    'GP-linked primary mental health, counselling, brief support, and health navigation.',
    'Check GP, Healthpoint, or Marlborough PHO current referral route',
    programmes: [
      'Primary mental health',
      'Brief intervention',
      'Counselling',
      'GP referral pathway',
      'Addiction support navigation',
    ],
    criteria: [
      'Mental health or addiction support need',
      'Usually GP or health referral route',
      'Crisis risk uses urgent crisis/emergency pathway',
      'Consent and safety plan checked',
    ],
  ),
  _Referral(
    'Youthline / What\'s Up',
    'Youth helplines',
    'Phone, text, online, and counselling support for young people.',
    'Youthline 0800 376 633 / text 234; What\'s Up 0800 942 8787',
    programmes: [
      'Youthline phone/text support',
      'Online chat',
      'Youth counselling',
      'After-hours youth support',
    ],
    criteria: [
      'Young person wants support',
      'Safe contact method checked',
      'Not a substitute for emergency response',
      'Client knows how/when to contact',
    ],
  ),
  _Referral(
    'Rape Crisis / Sexual Harm Support',
    'Sexual harm',
    'Sexual harm crisis support, advocacy, counselling pathways, and specialist referral.',
    '0800 88 33 00; confirm current local pathway',
    programmes: [
      'Sexual harm crisis support',
      'Advocacy',
      'Counselling referral',
      'Specialist support navigation',
    ],
    criteria: [
      'Sexual harm disclosure or support need',
      'Consent, safety, and privacy checked',
      'Safe contact method recorded',
      'Immediate danger escalated to 111',
    ],
  ),
  _Referral(
    'Wairau Hospital Emergency Department',
    'Emergency / medical crisis',
    '24-hour emergency department for life-threatening and urgent physical or mental-health emergencies.',
    '03 520 9999; Wairau Hospital, Hospital Road / 30 Hospital Road, Blenheim',
    programmes: [
      'Emergency Department',
      'Urgent medical care',
      'Severe mental-health emergency access',
      'After-hours crisis access point',
    ],
    criteria: [
      'Immediate danger or serious risk',
      'Life-threatening or urgent health need',
      'No appointment required',
      'Use 111 if immediate emergency transport/police/fire required',
    ],
  ),
  _Referral(
    'Marlborough Community Assessment Team',
    'Acute mental health',
    '24/7 adult acute/crisis mental-health assessment, intervention, and short-term follow-up.',
    '0800 948 497, press 2; Wairau Hospital, Blenheim',
    programmes: [
      '24/7 crisis mental-health triage',
      'Adult acute assessment',
      'Short-term follow-up',
      'Corrections / GP / clinical referral pathway',
    ],
    criteria: [
      'Adult acute mental-health concern',
      'Self-referral or direct phone referral accepted',
      'Crisis or suicide-risk concern',
      'Use ED/111 if immediate physical danger',
    ],
  ),
  _Referral(
    'Community Mental Health',
    'Specialist adult mental health',
    'Assessment, intervention, and ongoing treatment for adults with serious psychiatric disorder.',
    '0800 948 497; Wairau Hospital, Hospital Road, Blenheim',
    programmes: [
      'Adult mental-health assessment',
      'Ongoing treatment',
      'Maternal mental-health support',
      'Secondary mental-health care',
    ],
    criteria: [
      'Serious or persistent mental-health need',
      'Self-referral or GP referral',
      'Free public secondary mental-health service',
      'Not the same as immediate ED emergency care',
    ],
  ),
  _Referral(
    'iCAMHS Blenheim',
    'Child / youth mental health',
    'Secondary mental-health assessment and treatment for infants, children and adolescents with moderate to severe disturbance.',
    '03 520 9905; after hours 03 520 9999; crisis triage 0800 948 497 option 2; 22 Queen Street, Blenheim',
    programmes: [
      'Child and adolescent mental-health assessment',
      'Infant mental-health support',
      'Youth mental-health treatment',
      '24/7 suicide-risk assessment pathway',
    ],
    criteria: [
      'Infant, child, or adolescent concern',
      'Moderate to severe mental-health disturbance',
      'Family, school, GP, or self contact pathway',
      'After-hours cover via GP/A&E/CAMHS',
    ],
  ),
  _Referral(
    'Supporting Families Marlborough',
    'Whanau mental-health support',
    'Family/whanau support, education, advocacy, and groups for people supporting someone with mental illness or addiction.',
    '03 577 5491; support@sfmarlb.org.nz; Unit 3 / 19 Henry Street, Blenheim',
    programmes: [
      'Family / whanau support',
      'Mental-health education',
      'Advocacy',
      'Support groups',
      'Addiction-family support',
    ],
    criteria: [
      'Supporting someone with mental illness or addiction',
      'Self-referral accepted',
      'GP / Health NZ / Corrections referrals accepted',
      'Free and confidential support',
    ],
  ),
  _Referral(
    'Addictions Service Nelson Marlborough',
    'Addiction',
    'Community detox, opioid substitution treatment, training, addiction support, and referrals from people, whanau, or services.',
    '03 520 9908; after-hours crisis 0800 948 497; Hospital Road, Witherlea, Blenheim',
    programmes: [
      'Community detox',
      'Opioid substitution treatment',
      'Addiction support',
      'Training',
      'Whanau / service referral',
    ],
    criteria: [
      'Alcohol or drug concern',
      'Self-referral or whanau/service referral',
      'Phone directly if affected by addiction',
      'After-hours crisis uses 0800 948 497',
    ],
  ),
  _Referral(
    'St Marks Addiction Residential Treatment Centre',
    'Residential addiction treatment',
    'Residential alcohol/drug treatment, supportive social detox, and after-care.',
    '03 578 0459; 61 Main Street, Blenheim',
    programmes: [
      'Residential alcohol/drug treatment',
      'Supportive social detox',
      'After-care',
      'Private-paying residential treatment',
    ],
    criteria: [
      'Residential treatment needed',
      'Mostly via Community Alcohol and Drug Services / NGOs',
      'Not a casual walk-in intake',
      'Bond may be payable on admission',
    ],
  ),
  _Referral(
    'Oranga Toi Ora Maori Mental Health',
    'Maori mental health',
    'Specialist kaupapa Maori adult mental-health assessment, care management, crisis, and routine support.',
    '0800 948 497; Wairau Hospital, Hospital Road, Blenheim',
    programmes: [
      'Kaupapa Maori mental-health assessment',
      'Care management',
      'Crisis support',
      'Routine adult support',
    ],
    criteria: [
      'Adult Maori mental-health support need',
      'GP / Health NZ / in-house / community health referral',
      'Hospital-based access',
      'Crisis risk escalated through CAT/ED',
    ],
  ),
  _Referral(
    'Whanau Awhina Plunket Blenheim Clinic',
    'Parenting / child health',
    'Well Child / Tamariki Ora and parenting support for families with pepi and young children.',
    '0800 184 803; southern.region@plunket.org.nz; 16 Henry Street, Blenheim',
    programmes: [
      'Well Child / Tamariki Ora',
      'Parenting support',
      'Drop-in clinic',
      'Appointments by phone',
    ],
    criteria: [
      'Pregnancy, baby, or young child support need',
      'Thursday drop-in 9:00am-11:00am',
      'Phone for appointment outside drop-in',
      'Family consents to child health contact',
    ],
  ),
  _Referral(
    'Oranga Tamariki Blenheim',
    'Care protection / youth justice',
    'Care and protection, youth justice, adoption services, and community liaison social work.',
    '0508 326 459; contact@ot.govt.nz; Level 5, PORSE House, 9-15 Market Street, Blenheim',
    programmes: [
      'Care and protection',
      'Youth justice',
      'Adoption services',
      'Report of concern',
      'Community liaison',
    ],
    criteria: [
      'Child safety or wellbeing concern',
      'Anyone can make contact/report concern',
      'No referral required',
      'Immediate danger escalated to 111',
    ],
  ),
  _Referral(
    'Marlborough Sexual Violence Support Centre',
    'Sexual violence',
    'Specialist support for survivors of sexual harm, immediate help, counselling/support, groups, and programmes.',
    'Crisis 0800 437 077; office 03 577 9939; admin@marlbrefuge.com; 52 Scott Street, Blenheim',
    programmes: [
      'Sexual harm crisis support',
      'Immediate help',
      'Counselling / support',
      'Groups and programmes',
      'Decision support',
    ],
    criteria: [
      'Sexual harm disclosure or support need',
      'Contact/referral/appointment/walk-in listed',
      'Free service',
      'Child-friendly and LGBTQIA+ friendly',
    ],
  ),
  _Referral(
    'SASH',
    'Sexual harm support',
    'Sexual Abuse Support and Healing for all genders; young people, court support, ACC sensitive claims, advocacy, and crisis response.',
    '0800 777 929; sash@sash.co.nz; Blenheim office stated, address not publicly listed',
    programmes: [
      'Sexual abuse support and healing',
      'Young people support',
      'Court support',
      'ACC sensitive claims support',
      'Sexual harm advocacy',
      '24-hour crisis response',
    ],
    criteria: [
      'Sexual harm support need',
      'All genders / ages / ethnicities supported',
      'Self-referral or agency referral',
      'Phone/online referral system',
    ],
  ),
  _Referral(
    'Victim Support',
    'Crime / trauma support',
    '24/7 emotional support, practical assistance, advocacy, information, and referral for crime, trauma, and suicide impacts.',
    '0800 842 846; nationwide 24/7 support available in Blenheim',
    programmes: [
      'Emotional support',
      'Practical assistance',
      'Advocacy',
      'Information and referral',
      'Crime / trauma / suicide impact support',
    ],
    criteria: [
      'Person directly affected, whanau, or witness',
      'Phone access immediate',
      'Free support',
      'Use emergency services if immediate danger',
    ],
  ),
  _Referral(
    'Alzheimers Marlborough',
    'Dementia / ageing',
    'Dementia support, carer support, education, support groups, and day respite through Wither Road Club.',
    '03 577 6172; office.marlb@alzheimers.org.nz; 8 Wither Road, Blenheim',
    programmes: [
      'Dementia support',
      'Carer support',
      'Education',
      'Support groups',
      'Wither Road Club day respite',
    ],
    criteria: [
      'Dementia diagnosis or suspected dementia support need',
      'Family/carer support need',
      'Club requires medical referral after diagnosis',
      'Membership donation model exists',
    ],
  ),
  _Referral(
    'Older Persons Mental Health',
    'Older persons mental health',
    'Specialist consultation, assessment, and care coordination for older adults with significant mental illness and/or cognitive decline.',
    '0800 948 497; Wairau Hospital, Blenheim',
    programmes: [
      'Older adult mental-health consultation',
      'Assessment',
      'Care coordination',
      'Cognitive decline pathway',
    ],
    criteria: [
      'Older adult with significant mental illness or cognitive decline',
      'GP referral for community team',
      'Inpatient admission via GP or Health NZ',
      'Crisis risk uses CAT/ED',
    ],
  ),
  _Referral(
    'CCS Disability Action Blenheim',
    'Disability',
    'Pan-disability advocacy and support; local access point for disability services.',
    '03 578 1170 or 0800 227 2255; Blenheim.Admin@ccsDisabilityAction.org.nz; 9 Sinclair Street, Blenheim',
    programmes: [
      'Pan-disability advocacy',
      'Disability support',
      'Local disability service navigation',
      'Mobility / access support',
    ],
    criteria: [
      'Disability support or access need',
      'Referral may apply',
      'Some charges may apply',
      'Mobility parking noted',
    ],
  ),
  _Referral(
    'Needs Assessment Service Marlborough',
    'Disability / older persons access',
    'Needs assessment and service coordination for disability, mental-health support needs, and age-related support needs.',
    '0800 244 300; Marlborough Health Hub, 22 Queen Street, Blenheim',
    programmes: [
      'Needs assessment',
      'Service coordination',
      'Disability support access',
      'Age-related support access',
      'Mental-health support needs access',
    ],
    criteria: [
      'Disability, age-related, or support-needs assessment required',
      'Self-referral or healthcare provider referral',
      'Assessment can happen at home or hospital',
      'Support person can attend',
    ],
  ),
  _Referral(
    'Hospice Marlborough',
    'Palliative / bereavement',
    'Specialist palliative care at home, hospital, and hospice inpatient unit, plus family/whanau and bereavement support.',
    '03 578 9492; hospice.marlborough@mht.org.nz; Gate 2, Wairau Hospital, Blenheim',
    programmes: [
      'Specialist palliative care',
      'Home care',
      'Hospice inpatient unit',
      'Family / whanau support',
      'Bereavement support',
    ],
    criteria: [
      'Palliative care or bereavement support need',
      'Early referrals encouraged',
      'Self-referrals accepted by phone',
      'Free to patients and families',
    ],
  ),
  _Referral(
    'ElderLink NZ',
    'Older people / food support',
    'Practical support, food parcels, welfare checks, social connection, and community connection for over-65s.',
    '021 081 80827; elderlinknz@gmail.com; 4/72 Market Street, Blenheim',
    programmes: [
      'Food parcels',
      'Welfare checks',
      'Social connection',
      'Practical support',
      'Over-65 support',
    ],
    criteria: [
      'Over-65 in Marlborough',
      'Cost pressure or practical support need',
      'Foodbank hours checked before sending client',
      'Safe contact details recorded',
    ],
  ),
  _Referral(
    'Salvation Army Blenheim Community Ministries',
    'Food / budgeting / social work / housing',
    'Food parcels, budgeting advice, life-skills and parenting courses, social work, youth development, social housing units, and support.',
    '03 578 0862; blenheim.corps@salvationarmy.org.nz; 35 George Street, Blenheim',
    programmes: [
      'Food parcels',
      'Budgeting advice',
      'Life-skills courses',
      'Parenting courses',
      'Social work',
      'Youth development',
      'Social housing units',
    ],
    criteria: [
      'Food, budgeting, social work, or housing support need',
      'Contact office directly',
      'Office hours checked before sending client',
      'Welfare support is public-facing',
    ],
  ),
  _Referral(
    'Crossroads Marlborough',
    'Food / community hub',
    'Community kitchen/cafe, affordable meals, shared Wednesday evening meal, Urban Harvest food parcels, connection, and practical support.',
    '03 578 5395; info@crossroads.org.nz; 2 Redwood Street, Blenheim',
    programmes: [
      'Community kitchen',
      'Cafe / affordable meals',
      'Wednesday evening meal',
      'Urban Harvest food parcels',
      'Connection and practical support',
    ],
    criteria: [
      'Immediate kai or practical support need',
      'Public drop-in model',
      'Anyone can come in',
      'Weekday hours checked before sending client',
    ],
  ),
  _Referral(
    'St Vincent de Paul Marlborough',
    'Faith-based community support',
    'Visible local shop/contact point for charitable support and direction to nearest St Vincent de Paul help.',
    '03 577 8378; 63 High Street, Blenheim',
    programmes: [
      'Local Vinnies shop contact',
      'Charitable support navigation',
      'Faith-based community support',
      'Practical support referral',
    ],
    criteria: [
      'Client needs local charitable support direction',
      'Detailed welfare intake not clearly published',
      'Phone/shop contact before relying on assistance',
      'Good backup practical-support pathway',
    ],
  ),
  _Referral(
    'Workbridge Blenheim',
    'Employment support',
    'Employment support for jobseekers, especially people with disability, injury, or health-condition barriers.',
    '0508 858 858; info@workbridge.co.nz; 1/56 Scott Street, Blenheim',
    programmes: [
      'Employment support',
      'Disability employment support',
      'Injury / health-condition employment support',
      'Community-space meetings',
    ],
    criteria: [
      'Jobseeker with disability, injury, or health barrier',
      'Appointment-based support',
      'Employment goal identified',
      'Health/access barrier noted',
    ],
  ),
  _Referral(
    'REAP Marlborough',
    'Education / community learning',
    'Adult and community education, digital inclusion, learner support, school support, community development, and employability courses.',
    '03 578 7848; admin@reapmarlborough.co.nz; 65 Seymour Street, Blenheim',
    programmes: [
      'Adult education',
      'Community education',
      'Digital inclusion',
      'Learner support',
      'School support',
      'Community development',
      'Employability courses',
    ],
    criteria: [
      'Education, learning, or employability need',
      'Anyone can access centre services',
      'Fees vary by course/service',
      'Accessibility features listed',
    ],
  ),
  _Referral(
    'Literacy Aotearoa Northern South',
    'Education / work readiness',
    'Free adult literacy, numeracy, digital skills, work readiness, driver education, and financial capability learning.',
    '03 577 9080; marlborough@literacy.org.nz; Criterion Lane, Mayfield, Blenheim',
    programmes: [
      'Adult literacy',
      'Numeracy',
      'Digital skills',
      'Work readiness',
      'Driver education',
      'Financial capability learning',
    ],
    criteria: [
      'Adult 16+',
      'NZ citizen or resident for free programmes',
      'Appointment, walk-in, or referral welcomed',
      'Term-based classes / call to arrange',
    ],
  ),
  _Referral(
    'Te Hauora o Ngati Rarua',
    'Maori health / Whanau Ora',
    'Kaupapa Maori whanau health service including Whanau Ora, rongoa Maori, health promotion, and support.',
    '03 577 8404; hauora@thonr.org; 64 Seymour Street, Blenheim',
    programmes: [
      'Whanau Ora',
      'Rongoa Maori',
      'Health promotion',
      'Whanau health support',
    ],
    criteria: [
      'Anyone can access Whanau Ora',
      'Referral may apply for some rongoa services',
      'Maori health / whanau support need',
      'Accessible bathroom, parking, and wheelchair access listed',
    ],
  ),
  _Referral(
    'Rangitane o Wairau Trust',
    'Iwi support / representation',
    'Iwi governance body responsible for cultural and social benefits for iwi members and broader representation/advocacy.',
    '03 578 6180; admin@rangitane.org.nz; Level 5, Rangitane House, 2 Main Street, Blenheim',
    programmes: [
      'Iwi representation',
      'Cultural support',
      'Social benefits for members',
      'Advocacy on social issues',
    ],
    criteria: [
      'Primarily for registered iwi members',
      'Not a general crisis service',
      'Cultural/iwi connection support need',
      'Use other crisis services for immediate risk',
    ],
  ),
  _Referral(
    'English Language Partners Marlborough',
    'Migrant / refugee / ESOL',
    'English language and settlement services for refugees and migrants.',
    '03 579 2460; marlborough@englishlanguage.org.nz; Marlborough House, 21 Henry Street, Blenheim',
    programmes: [
      'English language learning',
      'Settlement support',
      'Refugee support',
      'Migrant support',
      'ESOL programmes',
    ],
    criteria: [
      'Refugee or migrant support need',
      'Anyone can access',
      'Some programmes free for residents/citizens',
      'Some programmes have costs',
    ],
  ),
  _Referral(
    'Volunteer Marlborough',
    'Volunteer matching / community sector',
    'Matches volunteers with community organisations, reverse recruitment, training, and sector support.',
    '03 577 9388; vm@volunteermarlborough.org.nz; remote / by appointment',
    programmes: [
      'Volunteer matching',
      'Reverse recruitment',
      'Volunteer training',
      'Community sector support',
    ],
    criteria: [
      'Client wants volunteering or community connection',
      'Organisation needs volunteer support',
      'Contact by phone/email',
      'Appointments available if meeting needed',
    ],
  ),
];

const _requestCategories = {
  'MSD/EH',
  'Public housing',
  'Financial support',
  'CMM',
  'Referral',
  'Programme',
  'EH readiness',
};

const _urgencyActions = [
  _UrgencyAction(
    label: 'Walk-in start',
    icon: Icons.front_hand_outlined,
    color: Color(0xFF4F8DF7),
    urgency: 'high',
    deadline: 'Today',
    noteType: 'Peer support housing note',
    presentingNeeds: [],
    roadblocks: ['Client initials only used in this working note'],
    focus: _CaseworkFocus.walkIn,
    logCategory: 'Intake',
    logText: 'Walk-in advocacy file opened',
  ),
  _UrgencyAction(
    label: 'No safe place tonight',
    icon: Icons.night_shelter_outlined,
    color: Color(0xFFFF5A5F),
    urgency: 'critical',
    deadline: 'Tonight / before close of business',
    noteType: 'MSD call support note',
    socialHousingRating: 'Not checked',
    presentingNeeds: ['No safe place tonight', 'Emergency housing assessment'],
    situationUnderstanding: [
      'No safe place tonight',
      'MSD emergency housing assessment',
      'Needs support to explain situation to agency',
    ],
    immediateSafety: [
      'Safe place for tonight confirmed or escalated',
      'Immediate danger / family violence screened',
    ],
    documents: ['Photo ID checked or replacement pathway started'],
    msdCriteria: [
      'No safe or adequate accommodation available now',
      'No realistic whanau/friends/private option available tonight',
      'Unable to pay for suitable temporary accommodation without assistance',
    ],
    msdAdvocacy: ['MSD emergency housing assessment requested'],
    accommodationOptions: [
      'Emergency housing through MSD checked first',
      'Backpacker/hostel option checked for tonight',
      'Motel/supplier vacancy and suitability checked',
    ],
    referrals: ['Work and Income Blenheim'],
    roadblocks: [
      'Consent wording ready before calling agency',
      'Follow-up time/date set before ending contact',
    ],
    focus: _CaseworkFocus.msd,
    logCategory: 'Urgency',
    logText: 'Critical no-safe-place pathway started',
  ),
  _UrgencyAction(
    label: 'Transitional / CMM',
    icon: Icons.route_outlined,
    color: Color(0xFF31E981),
    urgency: 'high',
    deadline: 'Urgent supported housing pathway',
    noteType: 'CMM / MSD handover note',
    socialHousingRating: 'Rating review needed',
    presentingNeeds: ['Transitional housing needed'],
    situationUnderstanding: [
      'In emergency housing / motel now',
      'Transitional housing referral pathway',
    ],
    immediateSafety: ['Client knows next appointment/call time'],
    documents: ['Housing search evidence gathered'],
    msdCriteria: ['Housing search / alternative options evidence ready'],
    msdAdvocacy: [
      'MSD asked to check transitional housing options',
      'CMM EH social support/navigation requested',
      'CMM housing advocacy/navigation pathway requested',
    ],
    socialHousing: [
      'Public housing register status checked',
      'Rating review requested if needs have changed',
    ],
    housingApplications: ['Transitional housing referral need checked'],
    accommodationOptions: [
      'Plan for next business day made before placement ends',
    ],
    referrals: ['CMM Te Tau Ihu Blenheim', 'Work and Income Blenheim'],
    roadblocks: ['Decline/reason requested if agency cannot assist'],
    focus: _CaseworkFocus.msd,
    logCategory: 'Advocacy',
    logText: 'Transitional/CMM pathway started',
  ),
  _UrgencyAction(
    label: 'Housing apps',
    icon: Icons.assignment_outlined,
    color: Color(0xFFFFB020),
    urgency: 'medium',
    deadline: 'Before next appointment',
    noteType: 'Housing application support note',
    socialHousingRating: 'Application needed',
    presentingNeeds: ['Public housing register'],
    situationUnderstanding: [
      'Income or payment gap affecting accommodation',
      'Public housing register or rating review',
    ],
    immediateSafety: ['Client knows next appointment/call time'],
    documents: [
      'Photo ID checked or replacement pathway started',
      'Benefit/income evidence available',
      'Housing search evidence gathered',
    ],
    msdAdvocacy: ['Public housing register status checked'],
    socialHousing: [
      'Public housing register status checked',
      'Current rating/priority asked for and recorded',
    ],
    housingApplications: [
      'Public housing application started/updated',
      'Private rental search list started',
      'References/support letter need checked',
    ],
    referrals: [],
    roadblocks: ['Follow-up time/date set before ending contact'],
    focus: _CaseworkFocus.documents,
    logCategory: 'Applications',
    logText: 'Housing application checklist started',
  ),
  _UrgencyAction(
    label: 'Probation / bail',
    icon: Icons.gavel_outlined,
    color: Color(0xFFB56CFF),
    urgency: 'high',
    deadline: 'Before Corrections/MSD deadline',
    noteType: 'Peer support housing note',
    probationStatus: 'Check required',
    presentingNeeds: ['Probation / bail address issue'],
    situationUnderstanding: [
      'Probation / bail / release address issue',
      'No transport to appointment or accommodation',
    ],
    immediateSafety: ['Client knows next appointment/call time'],
    documents: [
      'Photo ID checked or replacement pathway started',
      'Current address / last stable address evidence checked',
    ],
    probationActions: [
      'Probation officer / Corrections contact identified',
      'Bail/release address requirement clarified',
    ],
    accommodationOptions: [
      'Emergency housing through MSD checked first',
      'Backpacker/hostel option checked for tonight',
    ],
    referrals: ['Work and Income Blenheim', 'CMM Te Tau Ihu Blenheim'],
    roadblocks: [
      'Consent wording ready before calling agency',
      'Decline/reason requested if agency cannot assist',
    ],
    focus: _CaseworkFocus.probation,
    logCategory: 'Probation',
    logText: 'Probation/bail address pathway started',
  ),
];
