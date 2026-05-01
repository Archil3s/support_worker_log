class AppSettings {
  const AppSettings({
    this.hourlyRate = 43,
    this.fuelRate = 1.17,
    this.accRate = 0.017,
    this.gstRate = 0.15,
    this.kiwiSaverEnabled = false,
    this.kiwiSaverRate = 0.03,
  });

  final double hourlyRate;
  final double fuelRate;
  final double accRate;
  final double gstRate;
  final bool kiwiSaverEnabled;
  final double kiwiSaverRate;

  AppSettings copyWith({
    double? hourlyRate,
    double? fuelRate,
    double? accRate,
    double? gstRate,
    bool? kiwiSaverEnabled,
    double? kiwiSaverRate,
  }) {
    return AppSettings(
      hourlyRate: hourlyRate ?? this.hourlyRate,
      fuelRate: fuelRate ?? this.fuelRate,
      accRate: accRate ?? this.accRate,
      gstRate: gstRate ?? this.gstRate,
      kiwiSaverEnabled: kiwiSaverEnabled ?? this.kiwiSaverEnabled,
      kiwiSaverRate: kiwiSaverRate ?? this.kiwiSaverRate,
    );
  }
}
