import 'dart:isolate'; // 🌟 Added for background processing
import 'package:chess/chess.dart' as chess_lib;

/// 🌟 Pure Dart way to check if running on the web (Without depending on Flutter framework)
const bool _kIsWeb = bool.fromEnvironment('dart.library.js_interop') ||
    bool.fromEnvironment('dart.library.html');

/// Custom exception thrown when a user attempts to register a premove during their own turn.
class InvalidPremoveTurnException implements Exception {
  final String message;
  InvalidPremoveTurnException(this.message);
  @override
  String toString() => 'InvalidPremoveTurnException: $message';
}

/// Custom exception thrown to prevent UI freeze on the Web due to rapid spam clicks (Throttling).
class PremoveSpamException implements Exception {
  final String message;
  PremoveSpamException(this.message);
  @override
  String toString() => 'PremoveSpamException: $message';
}

/// Data holder class to pass arguments into the Isolate (as only primitive data types can be sent).
class _PremoveIsolateData {
  final SendPort sendPort;
  final String fen;
  final String fromSquare;
  final bool intelligence;

  _PremoveIsolateData(
    this.sendPort,
    this.fen,
    this.fromSquare,
    this.intelligence,
  );
}

class PremoveIntelligence {
  // 🌟 Holds the reference to the active isolate for cancellation capabilities.
  static Isolate? _activeIsolate;

  // 🌟 Stores the end time of the last web calculation to prevent event loop freezing (Throttling)
  static int _lastWebCalculationEndTime = 0;

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
          'It is currently your turn. Premoves can only be registered during the opponent\'s turn.',
        );
      }
    }

    // 🌟 2. Dedicated Web Handling (Isolates are not supported on Web)
    if (_kIsWeb) {
      // 🌟 Check the time elapsed since the last calculation to prevent spamming queued clicks
      int now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastWebCalculationEndTime < 200) {
        String errorMessage =
            '⚠️ [WEB] Spam tap detected! Time since last calculation: ${now - _lastWebCalculationEndTime}ms (Threshold: 200ms). Aborting to prevent UI freeze.';
        print(errorMessage);
        // Throw an exception instead of returning an empty list so it isn't treated as a valid response
        throw PremoveSpamException(errorMessage);
      }

      print(
        '🌐 [WEB] Premove Calculation running on Main Thread (Isolates not supported on Web)',
      );
      final stopwatch = Stopwatch()..start();

      // Execute directly on the main thread (Lightweight enough to avoid severe frame drops due to new optimizations)
      List<String> result = _coreCalculate(
        currentFen,
        fromSquare,
        intelligence,
      );

      stopwatch.stop();
      // 🌟 Record the end time of this calculation
      _lastWebCalculationEndTime = DateTime.now().millisecondsSinceEpoch;
      print('✅ [WEB] Result calculated in ${stopwatch.elapsedMilliseconds}ms.');

      return result;
    }

    // ========================================================
    // 🌟 FROM HERE ON: MOBILE & DESKTOP NATIVE ONLY
    // ========================================================

    // 3. Emergency Stop (Kill): If a previous calculation is still running, destroy it immediately!
    // This prevents CPU hogging and device slowdowns during rapid user clicks.
    if (_activeIsolate != null) {
      _activeIsolate!.kill(priority: Isolate.immediate);
      _activeIsolate = null;
      print(
        '🛑 [MAIN THREAD] ⚠️ ALERT: Rapid click detected! Killing previous Isolate to prevent Race Condition & free CPU.',
      );
    }

    // 4. Create communication port
    final receivePort = ReceivePort();

    // 5. Spawn a new Isolate and send it to the background
    try {
      print(
        '⚡ [MAIN THREAD] Offloading Premove calculation to Background Isolate...',
      );
      final stopwatch = Stopwatch()..start();

      _activeIsolate = await Isolate.spawn(
        _isolateEntryPoint,
        _PremoveIsolateData(
          receivePort.sendPort,
          currentFen,
          fromSquare,
          intelligence,
        ),
      );

      // Wait to receive the result from the Isolate
      final result = await receivePort.first as List<String>;

      stopwatch.stop();
      print(
        '✅ [MAIN THREAD] Received result from Isolate in ${stopwatch.elapsedMilliseconds}ms. Main UI remained 100% unblocked!',
      );

      return result;
    } finally {
      // 6. Always clean up resources after completion
      _activeIsolate = null;
      receivePort.close();
      print(
        '🧹 [MAIN THREAD] Isolate communication port closed & resources freed.',
      );
    }
  }

  /// Isolate entry point (This function runs entirely on a separate thread)
  static void _isolateEntryPoint(_PremoveIsolateData data) {
    try {
      print(
        '⚙️ [BACKGROUND ISOLATE] Worker started heavy simulation calculation for square: ${data.fromSquare}...',
      );
      List<String> moves = _coreCalculate(
        data.fen,
        data.fromSquare,
        data.intelligence,
      );
      print(
        '⚙️ [BACKGROUND ISOLATE] Calculation finished. Sending data back to Main Thread.',
      );
      data.sendPort.send(moves);
    } catch (e) {
      print('[ENGINE-FATAL-ERROR] Inside Isolate: $e');
      data.sendPort.send(<String>[]);
    }
  }

  /// Core calculation engine (Includes geometric algorithm + probability simulation)
  static List<String> _coreCalculate(
    String currentFen,
    String fromSquare,
    bool intelligence,
  ) {
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
          isValid = tempChess.move({
            'from': fromSquare,
            'to': targetSquare,
            'promotion': 'q',
          });
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
                // FIXED: Wrapped statements inside braces
                if (targetPiece == null && dr == dir) {
                  geometricValid = true;
                }
                // FIXED: Wrapped statements inside braces
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
                fromR,
                fromC,
                r,
                c,
                movingPiece,
                isWaitingPlayerWhite,
                board,
              );
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
        currentFen,
        fromSquare,
        pseudoLegalDestinations,
      );
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

  static bool _isPseudoLegal(
    int fromR,
    int fromC,
    int toR,
    int toC,
    String piece,
    bool isWhitePlayer,
    List<List<String?>> board,
  ) {
    int dr = toR - fromR;
    int dc = toC - fromC;
    String p = piece.toLowerCase();

    // FIXED: Wrapped all single-line conditionals inside braces
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
    print('================= PREMOVE ENGINE LOG =================');
    print('[ENGINE-START] Original FEN: $currentFen');
    print('[ENGINE-START] Moving piece from: $fromSquare');
    print(
      '[ENGINE-START] Initial candidate targets (Geometric): $pseudoLegalDestinations',
    );

    // 🌟 OPTIMIZATION: Use a Set to prevent duplicates and a list to track unverified targets.
    Set<String> trulyPossibleMoves = {};
    List<String> remainingTargets = List.from(pseudoLegalDestinations);

    try {
      // 🌟 MAGIC OPTIMIZATION: Instantiate the board ONLY ONCE!
      var baseBoard = chess_lib.Chess.fromFEN(currentFen);

      // Extract all legal opponent moves at this moment
      List<String> opponentMoves = List<String>.from(baseBoard.moves());
      print(
        '[ENGINE-INFO] Total opponent moves possible in this turn: ${opponentMoves.length}',
      );

      // Main loop checking against all possible opponent moves
      for (String oppMove in opponentMoves) {
        // 🌟 SECONDARY OPTIMIZATION: If all geometric targets are validated, stop simulating!
        if (remainingTargets.isEmpty) {
          print(
            '[ENGINE-OPT] All targets validated early. Breaking out of simulation.',
          );
          break;
        }

        // 1. Opponent makes their move on the primary board instance
        bool oppMoveSuccess = baseBoard.move(oppMove);

        // FIXED: Wrapped statements inside braces
        if (!oppMoveSuccess) {
          continue;
        }

        List<String> validatedInThisScenario = [];

        // 2. Now it's our turn. Are the remaining targets legal in this new state?
        for (String target in remainingTargets) {
          bool isValidPremove = false;
          try {
            isValidPremove = baseBoard.move({
              'from': fromSquare,
              'to': target,
              'promotion': 'q',
            });
          } catch (e) {
            isValidPremove = false;
          }

          if (isValidPremove) {
            // Move is valid! Record it.
            validatedInThisScenario.add(target);
            // 🌟 IMMEDIATELY undo our test move so the board is clean for the next target test in this scenario
            baseBoard.undo();
          }
        }

        // 3. Add validated targets to final set and remove them from the waiting list
        for (String validTarget in validatedInThisScenario) {
          trulyPossibleMoves.add(validTarget);
          remainingTargets.remove(validTarget);
          print(
            '[ENGINE-MATCH] Target $validTarget IS POSSIBLE if opponent plays: $oppMove',
          );
        }

        // 4. 🌟 Undo the opponent's move to revert the board to its original state for the next opponent move loop
        baseBoard.undo();
      }

      // Log squares that were determined to be completely impossible
      for (String unachievable in remainingTargets) {
        print(
          '[ENGINE-RESULT] Filtering out target: $unachievable (NOT possible in any future)',
        );
      }
    } catch (e) {
      print('[ENGINE-FATAL-ERROR] Simulation Filter crashed: $e');
      // If simulation crashes, return raw geometric list to prevent game-lock
      return pseudoLegalDestinations;
    }

    List<String> finalMoves = trulyPossibleMoves.toList();
    print('[ENGINE-END] Final approved targets: $finalMoves');
    print('==================================================');
    return finalMoves;
  }
}
