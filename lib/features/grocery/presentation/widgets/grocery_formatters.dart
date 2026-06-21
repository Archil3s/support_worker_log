String formatShoppingAmount(double amount, String unit) {
  if (unit == 'each') {
    final rounded = amount.ceil();
    return '$rounded ${rounded == 1 ? 'item' : 'items'}';
  }
  if (unit == 'g' && amount >= 1000) {
    return '${cleanNumber(amount / 1000)} kg';
  }
  if (unit == 'ml' && amount >= 1000) {
    return '${cleanNumber(amount / 1000)} L';
  }
  return '${cleanNumber(amount)} $unit';
}

String formatPrice(double value) => '\$${value.toStringAsFixed(2)}';

String formatOptionalPrice(double? value) {
  return value == null ? 'Price unavailable' : formatPrice(value);
}

String cleanNumber(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}
