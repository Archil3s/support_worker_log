enum AppMode { work, personal, massage, paye }

extension AppModeLabel on AppMode {
  String get label {
    switch (this) {
      case AppMode.work:
        return 'Work';
      case AppMode.personal:
        return 'Personal';
      case AppMode.massage:
        return 'Massage';
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
