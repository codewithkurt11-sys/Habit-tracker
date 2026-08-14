import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/models/user_settings.dart';

void main() {
  test('dashboard customization draft survives repeated rebuild-style copies', () {
    final saved = DashboardConfig();
    final draft = DashboardConfig.fromMap(saved.toMap());

    draft.showTasks = false;
    draft.showQuickActions = false;

    final rebuiltView = draft;
    expect(rebuiltView.showTasks, isFalse);
    expect(rebuiltView.showQuickActions, isFalse);

    final persisted = DashboardConfig.fromMap(draft.toMap());
    expect(persisted.showTasks, isFalse);
    expect(persisted.showQuickActions, isFalse);
    expect(saved.showTasks, isTrue);
    expect(saved.showQuickActions, isTrue);
  });
}
