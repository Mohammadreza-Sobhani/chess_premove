import 'package:chess_premove/chess_premove.dart';

void main() async {
  print('--- Chess Premove Intelligence Example ---');

  // ۱. وضعیت فعلی بازی (مثلا شروع بازی)
  String currentFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  // ۲. خانه‌ای که کاربر روی آن کلیک کرده تا پری‌موو ثبت کند
  String tappedSquare = 'd8'; // مثال: وزیر سیاه در خانه d8

  print('Current FEN: $currentFen');
  print('Tapped Square: $tappedSquare');
  print('Calculating premoves in background...\n');

  try {
    // ۳. محاسبه هوشمند حرکات در پس‌زمینه (بدون درگیری رابط کاربری)
    List<String> validPremoves =
        await PremoveIntelligence.calculatePremovesAsync(
      currentFen,
      tappedSquare,
      intelligence: true,
    );

    print('✅ Valid premove destinations for $tappedSquare: $validPremoves');
  } catch (e) {
    if (e is InvalidPremoveTurnException) {
      print('❌ Error: الان نوبت شماست! پری‌موو فقط در نوبت حریف مجاز است.');
    } else {
      print('❌ Unexpected Error: $e');
    }
  }
}
