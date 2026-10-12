import 'package:flutter_test/flutter_test.dart';
import 'package:stokpilot/core/format.dart';

void main() {
  test('Currency conversions use Turkish decimal commas', () {
    expect(parseMoney('19,99'), 1999);
    expect(parseMoney('1.234,50'), 123450);
    expect(money(1250).contains('12'), isTrue);
  });
  test('Stock precision is preserved in milli-units', () {
    expect(parseQty('1,250'), 1250);
    expect(quantity(1250), '1.25');
    expect(parseQty('-1'), throwsFormatException);
  });
}
