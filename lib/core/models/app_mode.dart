enum AppMode { work, personal, massage, mood, cleaning, casework, paye }

extension AppModeLabel on AppMode {
  String get label {
    switch (this) {
      case AppMode.work:
        return 'Work';
      case AppMode.personal:
        return 'Personal';
      case AppMode.massage:
        return 'Massage';
      case AppMode.mood:
        return 'Mood Tracker';
      case AppMode.cleaning:
        return 'Cleaning';
      case AppMode.casework:
        return 'Casework';
      case AppMode.paye:
        return 'PAYE job';
    }
  }
}

AppMode appModeFromName(String? value) {
  return AppMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => AppMode.work,
  );
}
