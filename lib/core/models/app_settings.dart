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

  Map<String, dynamic> toJson() {
    return {
      'hourlyRate': hourlyRate,
      'fuelRate': fuelRate,
      'accRate': accRate,
      'gstRate': gstRate,
      'kiwiSaverEnabled': kiwiSaverEnabled,
      'kiwiSaverRate': kiwiSaverRate,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    double readDouble(String key, double fallback) {
      final value = json[key];
      if (value is num) return value.toDouble();
      return fallback;
    }

    bool readBool(String key, bool fallback) {
      final value = json[key];
      if (value is bool) return value;
      return fallback;
    }

    return AppSettings(
      hourlyRate: readDouble('hourlyRate', 43),
      fuelRate: readDouble('fuelRate', 1.17),
      accRate: readDouble('accRate', 0.017),
      gstRate: readDouble('gstRate', 0.15),
      kiwiSaverEnabled: readBool('kiwiSaverEnabled', false),
      kiwiSaverRate: readDouble('kiwiSaverRate', 0.03),
    );
  }
}
