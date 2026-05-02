import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/pay_period_utils.dart';
import '../../core/utils/totals.dart';
import '../../shared/widgets/review_row.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/stat_grid.dart';

class TaxScreen extends StatefulWidget {
  const TaxScreen({super.key});

  @override
  State<TaxScreen> createState() => _TaxScreenState();
}

class _TaxScreenState extends State<TaxScreen> {
  late PayPeriodRange selectedRange;

  @override
  void initState() {
    super.initState();
    selectedRange = currentFortnight();
  }

  void showCurrentPeriod() {
    setState(() => selectedRange = currentFortnight());
  }

  void showPreviousPeriod() {
    setState(() => selectedRange = selectedRange.previous);
  }

  void showNextPeriod() {
    setState(() => selectedRange = selectedRange.next);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final settings = appState.settings;

    final periodEntries = entriesInRange(appState.entries, selectedRange);

    final double gross = totalEarnings(periodEntries, settings);
    final double acc = gross * settings.accRate;
    final double kiwiSaver = settings.kiwiSaverEnabled
        ? gross * settings.kiwiSaverRate
        : 0.0;
    final double gst = gross * settings.gstRate;
    final double net = gross - acc - kiwiSaver - gst;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Tax Period',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${formatDate(selectedRange.start)} - ${formatDate(selectedRange.end)}',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: showPreviousPeriod,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Previous'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: showCurrentPeriod,
                    icon: const Icon(Icons.today_outlined),
                    label: const Text('Current'),
                  ),
                  OutlinedButton.icon(
                    onPressed: showNextPeriod,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StatGrid(
          cards: [
            StatCard(title: 'Gross', value: money(gross)),
            StatCard(title: 'ACC', value: '-${money(acc)}'),
            StatCard(title: 'KiwiSaver', value: '-${money(kiwiSaver)}'),
            StatCard(title: 'GST', value: '-${money(gst)}'),
            StatCard(title: 'Net Estimate', value: money(net)),
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Period Summary',
          child: Column(
            children: [
              ReviewRow(label: 'Entries', value: '${periodEntries.length}'),
              ReviewRow(
                label: 'Hours',
                value: totalHours(periodEntries).toStringAsFixed(2),
              ),
              ReviewRow(
                label: 'Kilometres',
                value: totalKilometres(periodEntries).toStringAsFixed(1),
              ),
              ReviewRow(label: 'Gross income', value: money(gross)),
              ReviewRow(
                label: 'ACC levy',
                value:
                    '-${money(acc)} (${(settings.accRate * 100).toStringAsFixed(2)}%)',
              ),
              ReviewRow(
                label: 'KiwiSaver',
                value: settings.kiwiSaverEnabled
                    ? '-${money(kiwiSaver)} (${(settings.kiwiSaverRate * 100).toStringAsFixed(1)}%)'
                    : 'Off',
              ),
              ReviewRow(
                label: 'GST estimate',
                value:
                    '-${money(gst)} (${(settings.gstRate * 100).toStringAsFixed(1)}%)',
              ),
              const Divider(),
              ReviewRow(label: 'Net take-home estimate', value: money(net)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Tax Settings',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('KiwiSaver deduction'),
                subtitle: Text(
                  '${(settings.kiwiSaverRate * 100).toStringAsFixed(1)}% of gross',
                ),
                value: settings.kiwiSaverEnabled,
                onChanged: (value) {
                  context.read<AppState>().updateSettings(
                    settings.copyWith(kiwiSaverEnabled: value),
                  );
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'These figures are estimates for planning only. Confirm final tax, GST, ACC, and KiwiSaver obligations with the official sources or an accountant.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
