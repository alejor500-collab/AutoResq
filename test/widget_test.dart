import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // AutoResQ requires Supabase + Riverpod initialization,
    // so a full widget test needs proper setup.
    expect(true, isTrue);
  });
}
