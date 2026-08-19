import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/logic/app_state.dart';

void main() {
  test('quick capture opens and closes deterministically', () {
    final state = AppState();

    expect(state.quickCaptureOpen, isFalse);
    state.toggleQuickCapture();
    expect(state.quickCaptureOpen, isTrue);
    state.hideQuickCapture();
    expect(state.quickCaptureOpen, isFalse);

    // Repeated hide calls are safe and remain closed.
    state.hideQuickCapture();
    expect(state.quickCaptureOpen, isFalse);
  });
}
