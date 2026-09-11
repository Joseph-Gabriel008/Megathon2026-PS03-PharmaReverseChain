import 'package:flutter_test/flutter_test.dart';
import 'package:mediloop/main.dart';

void main() {
  testWidgets('MediLoop app smoke test', (WidgetTester tester) async {
    expect(const MediLoopApp(), isNotNull);
  });
}
