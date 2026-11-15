import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/utils/display_text.dart';

void main() {
  test('maths letters and digits show as the plain ones; everything else as found', () {
    final italicX = String.fromCharCode(0x1D465);
    final italicF = String.fromCharCode(0x1D453);
    final boldA = String.fromCharCode(0x1D400);
    final boldTwo = String.fromCharCode(0x1D7D0);
    final planckH = String.fromCharCode(0x210E);
    final alpha = String.fromCharCode(0x1D6FC); // mathematical italic alpha: kept
    expect(displayText('If $italicF($italicX) = 2$italicX'), 'If f(x) = 2x');
    expect(displayText('$boldA$boldTwo $planckH'), 'A2 h');
    expect(displayText('angle $alpha'), 'angle $alpha');
    expect(displayText('plain text, ₹99 और हिंदी'), 'plain text, ₹99 और हिंदी');
  });
}
