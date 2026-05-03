enum InvoiceStatus { notSubmitted, submitted, paid }

extension InvoiceStatusLabel on InvoiceStatus {
  String get label {
    switch (this) {
      case InvoiceStatus.notSubmitted:
        return 'Not Submitted';
      case InvoiceStatus.submitted:
        return 'Submitted';
      case InvoiceStatus.paid:
        return 'Paid';
    }
  }

  bool get isOwed => this == InvoiceStatus.submitted;

  bool get isPaid => this == InvoiceStatus.paid;
}

InvoiceStatus invoiceStatusFromName(String? value) {
  return InvoiceStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => InvoiceStatus.notSubmitted,
  );
}
