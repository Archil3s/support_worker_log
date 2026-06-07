enum GoogleExportAccountScope {
  work,
  personal,
  paye;

  String get label {
    switch (this) {
      case GoogleExportAccountScope.work:
        return 'Work';
      case GoogleExportAccountScope.personal:
        return 'Personal';
      case GoogleExportAccountScope.paye:
        return 'PAYE job';
    }
  }
}
