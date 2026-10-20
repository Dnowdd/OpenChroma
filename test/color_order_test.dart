import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/ui/color_order.dart';

void main() {
  test('green and blue swapped on an RGB header means RBG strips', () {
    // Set to RGB: red looked red, green looked blue.
    expect(fixColorOrder('RGB', 'R', 'B').first, 'RBG');
  });

  test('the fix makes every channel land where it should', () {
    // Simulate strips of every order behind a header set to every order:
    // the header sends channel c at position current.indexOf(c), and the
    // strip shows the channel it expects there.
    for (final current in colorOrders) {
      for (final strip in colorOrders) {
        String seen(String c) => strip[current.indexOf(c)];
        final fixes = fixColorOrder(current, seen('R'), seen('G'));
        expect(fixes, contains(strip), reason: '$current -> $strip');
        expect(fixes.first, strip, reason: '$current -> $strip');
      }
    }
  });

  test('answers that cannot be right give no candidate', () {
    expect(fixColorOrder('RGB', 'G', 'G'), isEmpty);
    expect(fixColorOrder('OFF', 'R', 'G'), isEmpty);
  });
}
