import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/core/services/cloud_storage_service.dart';

void main() {
  test('Firebase and Google session hard expiry is one hour', () {
    expect(
      CloudStorageService.sessionMaxAgeForTesting,
      const Duration(hours: 1),
    );
  });
}
