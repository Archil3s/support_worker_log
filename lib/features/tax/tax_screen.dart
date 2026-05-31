import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/pay_period_utils.dart';
import '../../core/utils/totals.dart';

const double _annualPayeIncome = 69000;
const double _fortnightsPerYear = 365 / 14;

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
    final settings = context.read<AppState>().settings;
    setState(() {
      selectedRange = currentFortnight(
        anchorDate: settings.payPeriodAnchorDate,
      );
    });
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

    final gross = totalEarnings(periodEntries, settings);
    final acc = gross * settings.accRate;
    final gst = gross * settings.gstRate;
    final annualPaye = _nzIncomeTax(_annualPayeIncome);
    final paye = annualPaye / _fortnightsPerYear;
    final kiwiSaver = settings.kiwiSaverEnabled
        ? gross * settings.kiwiSaverRate
        : 0.0;
    final setAside = acc + gst + kiwiSaver;
    final net = gross - setAside;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _Panel(
          title: 'Tax Period',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${formatDate(selectedRange.start)} - ${formatDate(selectedRange.end)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: showPreviousPeriod,
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: showCurrentPeriod,
                      icon: const Icon(Icons.today_outlined),
                      label: const Text('Current'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: showNextPeriod,
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('Next'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _MobileStatGrid(
          cards: [
            _TaxStat(title: 'Gross', value: money(gross)),
            _TaxStat(title: 'Set Aside', value: money(setAside)),
            _TaxStat(title: 'Net', value: money(net), green: true),
            _TaxStat(title: 'Entries', value: '${periodEntries.length}'),
          ],
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'Breakdown',
          child: Column(
            children: [
              _TaxLine(
                label: 'Hours',
                value: totalHours(periodEntries).toStringAsFixed(2),
              ),
              _TaxLine(
                label: 'Kilometres',
                value: totalKilometres(periodEntries).toStringAsFixed(1),
              ),
              _TaxLine(label: 'Gross income', value: money(gross)),
              _TaxLine(
                label: 'ACC',
                value:
                    '-${money(acc)} (${(settings.accRate * 100).toStringAsFixed(2)}%)',
              ),
              _TaxLine(
                label: 'GST',
                value:
                    '-${money(gst)} (${(settings.gstRate * 100).toStringAsFixed(1)}%)',
              ),
              _TaxLine(
                label: 'PAYE threshold check',
                value: '${money(_annualPayeIncome)} salary',
              ),
              _TaxLine(
                label: 'PAYE already taxed by job',
                value: '${money(paye)} / fortnight',
              ),
              _TaxLine(label: 'PAYE yearly estimate', value: money(annualPaye)),
              _TaxLine(
                label: 'KiwiSaver',
                value: settings.kiwiSaverEnabled
                    ? '-${money(kiwiSaver)} (${(settings.kiwiSaverRate * 100).toStringAsFixed(1)}%)'
                    : 'Off',
              ),
              const SizedBox(height: 8),
              _TaxLine(
                label: 'Estimated take-home',
                value: money(net),
                green: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'Settings',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'KiwiSaver deduction',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  '${(settings.kiwiSaverRate * 100).toStringAsFixed(1)}% of gross',
                  style: const TextStyle(color: Color(0xFF8396C7)),
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
                'Planning estimate only. Confirm final tax, GST, ACC, and KiwiSaver obligations with official sources or an accountant.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8396C7), height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

double _nzIncomeTax(double annualIncome) {
  final brackets = <_TaxBracket>[
    const _TaxBracket(limit: 15600, rate: 0.105),
    const _TaxBracket(limit: 53500, rate: 0.175),
    const _TaxBracket(limit: 78100, rate: 0.30),
    const _TaxBracket(limit: 180000, rate: 0.33),
    const _TaxBracket(limit: double.infinity, rate: 0.39),
  ];

  var remaining = annualIncome < 0 ? 0.0 : annualIncome;
  var previousLimit = 0.0;
  var tax = 0.0;

  for (final bracket in brackets) {
    if (remaining <= 0) break;

    final width = bracket.limit - previousLimit;
    final taxable = remaining < width ? remaining : width;
    tax += taxable * bracket.rate;
    remaining -= taxable;
    previousLimit = bracket.limit;
  }

  return tax;
}

class _TaxBracket {
  const _TaxBracket({required this.limit, required this.rate});

  final double limit;
  final double rate;
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF34405F)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F8DF7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileStatGrid extends StatelessWidget {
  const _MobileStatGrid({required this.cards});

  final List<_TaxStat> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 360 ? 1 : 2;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

class _TaxStat extends StatelessWidget {
  const _TaxStat({
    required this.title,
    required this.value,
    this.green = false,
  });

  final String title;
  final String value;
  final bool green;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      decoration: BoxDecoration(
        color: green ? const Color(0xFF0B301D) : const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: green ? const Color(0xFF128A45) : const Color(0xFF34405F),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: green
                    ? const Color(0xFF0D2A1D)
                    : const Color(0xFF13294D),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: green
                        ? const Color(0xFF31E981)
                        : const Color(0xFFD8E2FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              value,
              style: TextStyle(
                color: green ? const Color(0xFF31E981) : Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaxLine extends StatelessWidget {
  const _TaxLine({
    required this.label,
    required this.value,
    this.green = false,
  });

  final String label;
  final String value;
  final bool green;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: green ? const Color(0xFF0B301D) : const Color(0xFF20283B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: green ? const Color(0xFF128A45) : const Color(0xFF27324B),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF8396C7)),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: green ? const Color(0xFF31E981) : Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
