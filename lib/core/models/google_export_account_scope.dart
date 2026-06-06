enum GoogleExportAccountScope {
  work,
  personal;

  String get label {
    switch (this) {
      case GoogleExportAccountScope.work:
        return 'Work';
      case GoogleExportAccountScope.personal:
        return 'Personal';
    }
  }
}
