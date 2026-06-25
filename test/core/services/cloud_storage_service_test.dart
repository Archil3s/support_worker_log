import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/core/services/cloud_storage_service.dart';

void main() {
  test('app lock session window is three hours', () {
    expect(
      CloudStorageService.sessionMaxAgeForTesting,
      const Duration(hours: 3),
    );
  });
}
