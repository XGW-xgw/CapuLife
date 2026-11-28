import 'package:capulife_native/data/cap_store.dart';
import 'package:capulife_native/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shell renders', (tester) async {
    await tester.pumpWidget(
      CapuLifeNativeApp(store: CapStore.inMemory()),
    );
    expect(find.text('CapuLife'), findsWidgets);
  });
}
