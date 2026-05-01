import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../shared/widgets/section_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController hourlyRateController;
  late final TextEditingController fuelRateController;
  final clientController = TextEditingController();

  @override
  void initState() {
    super.initState();

    final settings = context.read<AppState>().settings;
    hourlyRateController = TextEditingController(
      text: settings.hourlyRate.toStringAsFixed(2),
    );
    fuelRateController = TextEditingController(
      text: settings.fuelRate.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    hourlyRateController.dispose();
    fuelRateController.dispose();
    clientController.dispose();
    super.dispose();
  }

  void saveRates() {
    final appState = context.read<AppState>();
    final settings = appState.settings;

    final hourlyRate = double.tryParse(hourlyRateController.text.trim());
    final fuelRate = double.tryParse(fuelRateController.text.trim());

    appState.updateSettings(
      settings.copyWith(
        hourlyRate: hourlyRate ?? settings.hourlyRate,
        fuelRate: fuelRate ?? settings.fuelRate,
      ),
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Rates saved')));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Rates',
          child: Column(
            children: [
              TextField(
                controller: hourlyRateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Hourly rate',
                  prefixText: '\$',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: fuelRateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Fuel / km rate',
                  prefixText: '\$',
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saveRates,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Rates'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Clients',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: clientController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'New client',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      context.read<AppState>().addClient(clientController.text);
                      clientController.clear();
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final client in appState.clients)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(client),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      context.read<AppState>().removeClient(client);
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
