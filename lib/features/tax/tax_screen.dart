import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/totals.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/stat_grid.dart';

class TaxScreen extends StatelessWidget {
  const TaxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final settings = appState.settings;

    final double gross = totalEarnings(appState.entries, settings);
    final double acc = gross * settings.accRate;
    final double kiwiSaver = settings.kiwiSaverEnabled
        ? gross * settings.kiwiSaverRate
        : 0.0;
    final double gst = gross * settings.gstRate;
    final double net = gross - acc - kiwiSaver - gst;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
          title: 'Tax Settings',
          child: SwitchListTile(
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
        ),
      ],
    );
  }
}
