import 'dart:isolate'; // 🌟 Added for background processing
import 'package:chess/chess.dart' as chess_lib;

/// Custom exception thrown when a user attempts to register a premove during their own turn.
class InvalidPremoveTurnException implements Exception {
  final String message;
  InvalidPremoveTurnException(this.message);
  @override
  String toString() => 'InvalidPremoveTurnException: $message';
}

/// Data holder class to pass arguments into the Isolate (as only primitive data types can be sent).
class _PremoveIsolateData {
  final SendPort sendPort;
  final String fen;
  final String fromSquare;
  final bool intelligence;

  _PremoveIsolateData(
      this.sendPort, this.fen, this.fromSquare, this.intelligence);
}

class PremoveIntelligence {
  // 🌟 Holds the reference to the active isolate for cancellation capabilities.
  static Isolate? _activeIsolate;

  /// The main asynchronous method called by the User Interface (UI).
  /// This method manages Isolates, cancels previous calculations, and prevents frame drops.
  static Future<List<String>> calculatePremovesAsync(
    String currentFen,
    String fromSquare, {
    bool intelligence = true,
  }) async {
    // 1. Initial, ultra-fast O(1) validation on the main thread.
    // If it is the wrong turn, no Isolate is spawned, and an error is thrown in milliseconds.
    List<String> fenParts = currentFen.split(' ');
    if (fenParts.length >= 2) {
      String turn = fenParts[1];
      String fenBoard = fenParts[0];
      int fromR = 8 - int.parse(fromSquare[1]);
      int fromC = fromSquare.codeUnitAt(0) - 97;
      List<String> rows = fenBoard.split('/');

      String? movingPiece;
      int cIndex = 0;
      for (int i = 0; i < rows[fromR].length; i++) {
        String char = rows[fromR][i];
        if (int.tryParse(char) != null) {
          cIndex += int.parse(char);
        } else {
          if (cIndex == fromC) {
            movingPiece = char;
            break;
          }
          cIndex++;
        }
      }

      if (movingPiece == null) {
        throw ArgumentError('No piece found on square $fromSquare.');
      }

      bool isWhitePiece = movingPiece == movingPiece.toUpperCase();
      if ((isWhitePiece && turn == 'w') || (!isWhitePiece && turn == 'b')) {
        throw InvalidPremoveTurnException(
            'It is currently your turn. Premoves can only be registered during the opponent\'s turn.');
      }
    }

    // 2. Emergency Stop (Kill): If a previous calculation is still running, destroy it immediately!
    // This prevents CPU hogging and device slowdowns during rapid user clicks.
    if (_activeIsolate != null) {
      _activeIsolate!.kill(priority: Isolate.immediate);
      _activeIsolate = null;
      print(
          '🛑 [MAIN THREAD] ⚠️ ALERT: Rapid click detected! Killing previous Isolate to prevent Race Condition & free CPU.');
    }

    // 3. Create communication port
    final receivePort = ReceivePort();

    // 4. Spawn a new Isolate and send it to the background
    try {
      print(
          '⚡ [MAIN THREAD] Offloading Premove calculation to Background Isolate...');
      final stopwatch = Stopwatch()..start();

      _activeIsolate = await Isolate.spawn(
        _isolateEntryPoint,
        _PremoveIsolateData(
            receivePort.sendPort, currentFen, fromSquare, intelligence),
      );

      // 5. Wait to receive the result from the Isolate
      final result = await receivePort.first as List<String>;

      stopwatch.stop();
      print(
          '✅ [MAIN THREAD] Received result from Isolate in ${stopwatch.elapsedMilliseconds}ms. Main UI remained 100% unblocked!');

      return result;
    } finally {
      // 6. Always clean up resources after completion
      _activeIsolate = null;
      receivePort.close();
      print(
          '🧹 [MAIN THREAD] Isolate communication port closed & resources freed.');
    }
  }

  /// Isolate entry point (This function runs entirely on a separate thread)
  static void _isolateEntryPoint(_PremoveIsolateData data) {
    try {
      print(
          '⚙️ [BACKGROUND ISOLATE] Worker started heavy AI calculation for square: ${data.fromSquare}...');
      List<String> moves =
          _coreCalculate(data.fen, data.fromSquare, data.intelligence);
      print(
          '⚙️ [BACKGROUND ISOLATE] Calculation finished. Sending data back to Main Thread.');
      data.sendPort.send(moves);
    } catch (e) {
      print('[AI-FATAL-ERROR] Inside Isolate: $e');
      data.sendPort.send(<String>[]);
    }
  }

  /// Core calculation engine (Includes geometric algorithm + probability AI)
  static List<String> _coreCalculate(
      String currentFen, String fromSquare, bool intelligence) {
    List<String> fenParts = currentFen.split(' ');
    String fenBoard = fenParts[0];

    List<List<String?>> board = _getBoardFromFen(fenBoard);

    int fromR = 8 - int.parse(fromSquare[1]);
    int fromC = fromSquare.codeUnitAt(0) - 97;
    String movingPiece = board[fromR][fromC]!;

    bool isWhitePiece = movingPiece == movingPiece.toUpperCase();
    bool isWaitingPlayerWhite = isWhitePiece;

    fenParts[1] = isWaitingPlayerWhite ? 'w' : 'b';
    fenParts[3] = '-';
    String fakeFen = fenParts.join(' ');

    List<String> pseudoLegalDestinations = [];

    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        String targetSquare = _getAlgebraic(r, c);
        var tempChess = chess_lib.Chess.fromFEN(fakeFen);

        bool isValid = false;
        try {
          isValid = tempChess
              .move({'from': fromSquare, 'to': targetSquare, 'promotion': 'q'});
        } catch (_) {}

        if (isValid) {
          pseudoLegalDestinations.add(targetSquare);
        } else {
          String? targetPiece = board[r][c];

          if (targetPiece?.toLowerCase() != 'k') {
            bool geometricValid = false;
            String p = movingPiece.toLowerCase();
            int dr = r - fromR;
            int dc = c - fromC;

            if (p == 'p') {
              int dir = isWaitingPlayerWhite ? -1 : 1;
              if (dc == 0) {
                if (targetPiece == null && dr == dir) {
                  geometricValid = true;
                }
                if (targetPiece == null &&
                    dr == 2 * dir &&
                    fromR == (isWaitingPlayerWhite ? 6 : 1) &&
                    board[fromR + dir][c] == null) {
                  geometricValid = true;
                }
              } else if (dc.abs() == 1 && dr == dir) {
                geometricValid = true;
              }
            } else {
              geometricValid = _isPseudoLegal(
                  fromR, fromC, r, c, movingPiece, isWaitingPlayerWhite, board);
            }

            if (geometricValid) {
              pseudoLegalDestinations.add(targetSquare);
            }
          }
        }
      }
    }

    pseudoLegalDestinations.remove(fromSquare);

    if (intelligence) {
      return filterPossiblePremoves(
          currentFen, fromSquare, pseudoLegalDestinations);
    } else {
      return pseudoLegalDestinations;
    }
  }

  static List<List<String?>> _getBoardFromFen(String fenBoard) {
    List<List<String?>> b = List.generate(8, (_) => List.filled(8, null));
    List<String> rows = fenBoard.split('/');
    for (int r = 0; r < 8; r++) {
      int c = 0;
      for (int i = 0; i < rows[r].length; i++) {
        String char = rows[r][i];
        if (int.tryParse(char) != null) {
          c += int.parse(char);
        } else {
          b[r][c] = char;
          c++;
        }
      }
    }
    return b;
  }

  static String _getAlgebraic(int row, int col) {
    String file = String.fromCharCode(97 + col);
    String rank = (8 - row).toString();
    return '$file$rank';
  }

  static bool _isPseudoLegal(int fromR, int fromC, int toR, int toC,
      String piece, bool isWhitePlayer, List<List<String?>> board) {
    int dr = toR - fromR;
    int dc = toC - fromC;
    String p = piece.toLowerCase();

    if (p == 'k') {
      return dr.abs() <= 1 && dc.abs() <= 1;
    }
    if (p == 'n') {
      return (dr.abs() == 2 && dc.abs() == 1) ||
          (dr.abs() == 1 && dc.abs() == 2);
    }
    if (p == 'r' || p == 'b' || p == 'q') {
      if (p == 'r' && (dr != 0 && dc != 0)) {
        return false;
      }
      if (p == 'b' && (dr.abs() != dc.abs())) {
        return false;
      }
      if (p == 'q' && (dr != 0 && dc != 0 && dr.abs() != dc.abs())) {
        return false;
      }

      int rStep = dr == 0 ? 0 : (dr > 0 ? 1 : -1);
      int cStep = dc == 0 ? 0 : (dc > 0 ? 1 : -1);
      int currR = fromR + rStep;
      int currC = fromC + cStep;
      while (currR != toR || currC != toC) {
        String? pathPiece = board[currR][currC];
        if (pathPiece != null) {
          bool isPathPieceWhite = pathPiece == pathPiece.toUpperCase();
          if (isPathPieceWhite == isWhitePlayer) {
            return false;
          }
        }
        currR += rStep;
        currC += cStep;
      }
      return true;
    }
    return false;
  }

  /// This function takes the list of geometric pseudo-legal premove candidates
  /// and returns only those that are legally playable in at least one scenario (one possible opponent move).
  static List<String> filterPossiblePremoves(
    String currentFen,
    String fromSquare,
    List<String> pseudoLegalDestinations,
  ) {
    print('================= PREMOVE AI LOG =================');
    print('[AI-START] Original FEN: $currentFen');
    print('[AI-START] Moving piece from: $fromSquare');
    print(
        '[AI-START] Initial candidate targets (Geometric): $pseudoLegalDestinations');

    List<String> trulyPossibleMoves = [];

    try {
      // Create a chess instance from the current state (It is the opponent's turn)
      var chess = chess_lib.Chess.fromFEN(currentFen);

      // Extract all legal opponent moves at this moment as SAN strings (e.g., e4, Nf3)
      // Using safe casting to List<String> to prevent unknown library errors
      List<String> opponentMoves = List<String>.from(chess.moves());
      print(
          '[AI-INFO] Total opponent moves possible in this turn: ${opponentMoves.length}');

      // Evaluate each target square found by our geometric algorithm in the previous step
      for (String target in pseudoLegalDestinations) {
        bool isPossibleInAnyScenario = false;

        // For this target square, simulate all possible futures (opponent moves)
        for (String oppMove in opponentMoves) {
          // Create a virtual board to simulate the future so the original FEN remains intact
          var simulationBoard = chess_lib.Chess.fromFEN(currentFen);

          // 1. The opponent makes their move (Future simulation)
          bool oppMoveSuccess = simulationBoard.move(oppMove);
          if (!oppMoveSuccess) {
            print('[AI-WARNING] Failed to simulate opponent move: $oppMove');
            continue;
          }

          // 2. Now it's our turn. Is our premove legal and possible in this new state?
          bool isValidPremove = false;
          try {
            isValidPremove = simulationBoard.move({
              'from': fromSquare,
              'to': target,
              'promotion': 'q', // Default promotion for testing purposes
            });
          } catch (e) {
            isValidPremove = false;
          }

          // If this premove is possible in even ONE opponent move, it means it's achievable!
          if (isValidPremove) {
            isPossibleInAnyScenario = true;
            print(
                '[AI-MATCH] Target $target IS POSSIBLE if opponent plays: $oppMove');
            break; // Finding one successful scenario is enough, no need to check the rest of the opponent's moves
          }
        }

        // If this move is achievable in the future, add it to the final list
        if (isPossibleInAnyScenario) {
          print('[AI-RESULT] Keeping target: $target');
          trulyPossibleMoves.add(target);
        } else {
          print(
              '[AI-RESULT] Filtering out target: $target (NOT possible in any future)');
        }
      }
    } catch (e) {
      print('[AI-FATAL-ERROR] AI Filter crashed: $e');
      // If the AI crashes, return the raw geometric list to prevent the game from locking up
      return pseudoLegalDestinations;
    }

    print('[AI-END] Final approved targets: $trulyPossibleMoves');
    print('==================================================');
    return trulyPossibleMoves;
  }
}
