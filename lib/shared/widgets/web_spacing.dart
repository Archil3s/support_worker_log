import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

bool useTightWebSpacing(BuildContext context) {
  return kIsWeb && MediaQuery.sizeOf(context).width >= 820;
}

EdgeInsets webPagePadding(BuildContext context) {
  return useTightWebSpacing(context)
      ? const EdgeInsets.fromLTRB(12, 8, 12, 16)
      : const EdgeInsets.fromLTRB(16, 12, 16, 24);
}
