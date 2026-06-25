import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:support_worker_log/core/models/app_mode.dart';
import 'package:support_worker_log/core/state/app_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('PAYE people deletion does not remove Work clients', () async {
    final state = AppState(warmGoogleAccounts: false);
    addTearDown(state.dispose);

    expect(state.addClient('Work client'), isTrue);
    state.setAppMode(AppMode.paye);
    expect(state.addClient('PAYE person'), isTrue);
    expect(state.addClient('PAYE second'), isTrue);

    expect(state.workClients, ['Work client']);
    expect(state.payeClients, ['PAYE person', 'PAYE second']);

    expect(state.removePayeClientFromList('PAYE person'), isTrue);
    await Future<void>.delayed(Duration.zero);

    expect(state.workClients, ['Work client']);
    expect(state.payeClients, ['PAYE second']);
  });

  test('clearing PAYE people leaves Work clients alone', () async {
    final state = AppState(warmGoogleAccounts: false);
    addTearDown(state.dispose);

    expect(state.addClient('Work client'), isTrue);
    state.setAppMode(AppMode.paye);
    expect(state.addClient('PAYE person'), isTrue);
    expect(state.addClient('PAYE second'), isTrue);

    expect(state.clearPayeClientList(), 2);
    await Future<void>.delayed(Duration.zero);

    expect(state.workClients, ['Work client']);
    expect(state.payeClients, isEmpty);
  });
}
