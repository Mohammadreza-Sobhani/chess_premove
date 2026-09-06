import 'package:chess_premove/chess_premove.dart';

void main() async {
  print('--- Chess Premove En Passant Example ---');

  // 1. Current game state (Black's turn, so White can register a premove).
  // This FEN represents a position where White has a pawn on g5 and Black has a pawn on h7.
  String currentFen =
      'rnb1k2r/pppp3p/2n5/2b3P1/8/N1P4N/PP1PBPP1/R1B1K2R b KQkq - 2 17';

  // 2. The square the user tapped to register a premove.
  // We are selecting the White pawn at g5.
  String tappedSquare = 'g5';

  print('Current FEN: $currentFen');
  print('Tapped Square: $tappedSquare (White Pawn)');
  print('Calculating premoves in background with strict validation...\n');

  try {
    // 3. Smart background calculation with Advanced Filtering.
    //
    // For the White pawn at g5, the core geometric engine initially suggests 3
    // pseudo-legal candidate destinations: [f6, g6, h6].
    //
    // Because 'intelligence: true' is passed, the custom simulation algorithm checks all
    // possible future moves for Black in this specific turn.
    //
    // The smart function filters out 'f6' because there is no scenario where White can
    // legally move to f6 in the very next turn. However, 'h6' is NOT filtered out!
    // Why? Because there is a possibility that Black plays 'h7-h5' (a two-square pawn advance),
    // which would make capturing on 'h6' via En Passant a strictly legal move for White.
    //
    // Therefore, the output correctly keeps the forward move and the potential En Passant capture,
    // returning the approved targets: [g6, h6].
    List<String> validPremoves =
        await PremoveIntelligence.calculatePremovesAsync(
      currentFen,
      tappedSquare,
      intelligence: true,
    );

    print('✅ Final approved targets for $tappedSquare:');
    print(validPremoves);

    // Expected Output:
    // [g6, h6]
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
