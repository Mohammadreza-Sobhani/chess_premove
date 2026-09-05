import 'package:chess_premove/chess_premove.dart';

void main() async {
  print('--- Chess Premove Intelligence Example ---');

  // 1. Current game state (e.g., standard starting position).
  // It is White's turn, so Black can validly register a premove.
  String currentFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  // 2. The square the user tapped to register a premove.
  // Example: The Black pawn at d7.
  String tappedSquare = 'd7';

  print('Current FEN: $currentFen');
  print('Tapped Square: $tappedSquare');
  print('Calculating premoves in background...\n');

  try {
    // 3. Smart background calculation (Zero UI blocking).
    //
    // For the black pawn at d7, the geometric engine initially suggests 4 pseudo-legal
    // destinations: c6, d6, e6, and d5.
    //
    // Because 'intelligence: true' is passed, the custom simulation engine evaluates all of White's possible
    // future moves. It realizes that the d7 pawn can never legally capture on c6 or e6
    // in the very next turn (as White cannot place any piece on those squares in just one move).
    // Therefore, the engine strictly filters out c6 and e6, returning only the
    // truly possible moves: [d6, d5].
    //
    // Note: If you set 'intelligence: false', the function will bypass the complex simulation
    // and simply return all 4 geometric squares [c6, d6, e6, d5]. This is highly useful
    // when you don't need strict logical validation and want to skip extra computations.
    List<String> validPremoves =
        await PremoveIntelligence.calculatePremovesAsync(
      currentFen,
      tappedSquare,
      intelligence: true,
    );

    print('✅ Valid premove destinations for $tappedSquare: $validPremoves');
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
