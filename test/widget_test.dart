import 'package:flutter_test/flutter_test.dart';

import 'package:dreamfocus/main.dart';

void main() {
  testWidgets('DreamFocus dashboard renders', (WidgetTester tester) async {
    await tester.pumpWidget(const DreamFocusApp());

    expect(find.text('DreamFocus'), findsOneWidget);
    expect(find.text('Start Focusing'), findsOneWidget);
    expect(find.text('Build your dream life'), findsOneWidget);
  });

  test('stopwatch formatting and session rewards use completed minutes', () {
    expect(formatDuration(const Duration(seconds: 59)), '00:00:59');
    expect(
      formatDuration(const Duration(hours: 5, minutes: 32, seconds: 47)),
      '05:32:47',
    );
    expect(coinsFor(const Duration(seconds: 59)), 0);
    expect(coinsFor(const Duration(minutes: 1)), 3);
    expect(coinsFor(const Duration(minutes: 1, seconds: 59)), 3);
    expect(coinsFor(const Duration(minutes: 2)), 6);
  });
}
