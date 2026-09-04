import 'package:chess_premove/chess_premove.dart';

void main() async {
  print('--- Chess Premove Advanced Filtering Example ---');

  // 1. Current game state (White's turn, FEN indicates a position where the Black Queen is active).
  String currentFen =
      'rnb1kbnr/ppp1pppp/8/3q4/8/8/PPPP1PPP/RNBQKBNR w KQkq - 0 3';

  // 2. The square the user tapped to register a premove.
  // We are selecting the Black Queen at d5.
  String tappedSquare = 'd5';

  print('Current FEN: $currentFen');
  print('Tapped Square: $tappedSquare (Black Queen)');
  print('Calculating premoves in background with strict validation...\n');

  try {
    // 3. Smart background calculation with Advanced Filtering.
    //
    // For the black queen at d5, the core geometric engine initially suggests 25
    // pseudo-legal candidate destinations:
    // [d8, b7, d7, f7, c6, d6, e6, a5, b5, c5, e5, f5, g5, h5, c4, d4, e4, b3, d3, f3, a2, d2, g2, d1, h1]
    //
    // Because 'intelligence: true' is passed, the simulation engine checks all 29 possible
    // future moves for White in this specific turn.
    //
    // After running the simulations, the engine determines that the Queen can NEVER
    // legally reach the following 3 squares in the very next turn, regardless of what White plays:
    // - b7
    // - f7
    // - d1
    //
    // Therefore, it intelligently filters out those 3 impossible targets,
    // returning only the 22 truly possible moves.
    List<String> validPremoves =
        await PremoveIntelligence.calculatePremovesAsync(
      currentFen,
      tappedSquare,
      intelligence: true, // Enabling the strict simulation filter
    );

    print('✅ Final approved targets for $tappedSquare:');
    print(validPremoves);

    // Expected Output:
    // [d8, d7, c6, d6, e6, a5, b5, c5, e5, f5, g5, h5, c4, d4, e4, b3, d3, f3, a2, d2, g2, h1]
  } catch (e) {
    if (e is InvalidPremoveTurnException) {
      print(
          '❌ Error: It is currently your turn! Premoves can only be registered during the opponent\'s turn.');
    } else {
      print('❌ Unexpected Error: $e');
    }
  }
}
