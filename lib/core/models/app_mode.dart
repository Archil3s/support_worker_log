enum AppMode { work, personal }

extension AppModeLabel on AppMode {
  String get label {
    switch (this) {
      case AppMode.work:
        return 'Work';
      case AppMode.personal:
        return 'Personal';
    }
  }
}

AppMode appModeFromName(String? value) {
  return AppMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => AppMode.work,
  );
}
