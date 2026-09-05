import 'package:chess_premove/chess_premove.dart';

void main() async {
  print('--- Chess Premove Fast Geometric Example ---');

  // 1. Current game state (e.g., standard starting position).
  // It is White's turn, so Black can validly register a premove.
  String currentFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  // 2. The square the user tapped to register a premove.
  // Example: The Black pawn at d7.
  String tappedSquare = 'd7';

  print('Current FEN: $currentFen');
  print('Tapped Square: $tappedSquare');
  print('Calculating raw geometric premoves (Bypassing simulations)...\n');

  try {
    // 3. Ultra-fast geometric background calculation.
    //
    // By setting 'intelligence: false', the heavy simulation engine is skipped entirely.
    // The package will simply evaluate standard piece movement rules ignoring complex
    // future game states.
    //
    // For the black pawn at d7, it immediately returns all 4 pseudo-legal
    // destinations: c6, d6, e6, and d5, without simulating if capturing on c6 or e6
    // is actually achievable in the very next turn.
    //
    // 🚀 PERFORMANCE BOOST: This mode provides maximum calculation speed. It is ideal
    // when you only need basic geometric validation and want to save CPU cycles,
    // as the filtering function (which performs heavy calculations) is bypassed.
    List<String> validPremoves =
        await PremoveIntelligence.calculatePremovesAsync(
      currentFen,
      tappedSquare,
      intelligence:
          false, // Disables the strict simulation filter for maximum speed
    );

    print('✅ Raw geometric destinations for $tappedSquare: $validPremoves');
    // Expected Output: [c6, d6, e6, d5]
  } catch (e) {
    if (e is InvalidPremoveTurnException) {
      print(
        '❌ Error: It is currently your turn! Premoves can only be registered during the opponent\'s turn.',
      );
    } else {
      print('❌ Unexpected Error: $e');
    }
  }
}
