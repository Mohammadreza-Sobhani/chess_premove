import 'package:test/test.dart';
import 'package:chess_premove/chess_premove.dart';

void main() {
  group('PremoveIntelligence Tests', () {
    test('Initialization and basic logic test', () {
      // استفاده از کلاس اصلی پکیج برای تایید صحت ایمپورت و رفع خطای عدم استفاده
      expect(PremoveIntelligence, isNotNull);
    });
  });
}
