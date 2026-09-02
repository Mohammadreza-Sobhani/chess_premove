import 'dart:isolate'; // 🌟 اضافه شده برای پردازش‌های پس‌زمینه
import 'package:chess/chess.dart' as chess_lib;

/// استثنای اختصاصی برای زمانی که نوبت بازی با کاربر است اما درخواست پری‌موو دارد
class InvalidPremoveTurnException implements Exception {
  final String message;
  InvalidPremoveTurnException(this.message);
  @override
  String toString() => 'InvalidPremoveTurnException: $message';
}

/// کلاس نگهدارنده داده‌ها برای ارسال به داخل ایزولیت (چون فقط داده‌های پایه قابل ارسال هستند)
class _PremoveIsolateData {
  final SendPort sendPort;
  final String fen;
  final String fromSquare;
  final bool intelligence;

  _PremoveIsolateData(
      this.sendPort, this.fen, this.fromSquare, this.intelligence);
}

class PremoveIntelligence {
  // 🌟 نگهداری رفرنس ایزولیت فعال برای قابلیت کشته شدن (Cancellation)
  static Isolate? _activeIsolate;

  /// متد ناهمگام (Async) و اصلی که رابط کاربری (UI) فراخوانی می‌کند.
  /// این متد مدیریت Isolateها، لغو محاسبات قبلی و جلوگیری از افت فریم را بر عهده دارد.
  static Future<List<String>> calculatePremovesAsync(
    String currentFen,
    String fromSquare, {
    bool intelligence = true,
  }) async {
    // ۱. اعتبارسنجی اولیه و فوق سریع (O(1)) در ترد اصلی
    // تا اگر نوبت اشتباه است، اصلا ایزولیت ساخته نشود و در کسری از میلی‌ثانیه خطا پرتاب شود.
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
        throw ArgumentError('هیچ مهره‌ای در خانه $fromSquare وجود ندارد.');
      }

      bool isWhitePiece = movingPiece == movingPiece.toUpperCase();
      if ((isWhitePiece && turn == 'w') || (!isWhitePiece && turn == 'b')) {
        throw InvalidPremoveTurnException(
            'اکنون نوبت شماست. پری‌موو فقط در نوبت حریف قابل ثبت است.');
      }
    }

    // ۲. توقف اضطراری (Kill): اگر پردازش قبلی هنوز در حال انجام است، آن را فوراً نابود کن!
    // این کار از اشغال شدن پردازنده و کند شدن گوشی هنگام کلیک‌های سریع کاربر جلوگیری می‌کند.
    if (_activeIsolate != null) {
      _activeIsolate!.kill(priority: Isolate.immediate);
      _activeIsolate = null;
      print(
          '🛑 [MAIN THREAD] ⚠️ ALERT: Rapid click detected! Killing previous Isolate to prevent Race Condition & free CPU.');
    }

    // ۳. ساخت پورت ارتباطی
    final receivePort = ReceivePort();

    // ۴. ساخت ایزولیت جدید و ارسال به پس‌زمینه
    try {
      print(
          '⚡ [MAIN THREAD] Offloading Premove calculation to Background Isolate...');
      final stopwatch = Stopwatch()..start();

      _activeIsolate = await Isolate.spawn(
        _isolateEntryPoint,
        _PremoveIsolateData(
            receivePort.sendPort, currentFen, fromSquare, intelligence),
      );

      // ۵. منتظر ماندن برای دریافت نتیجه از ایزولیت
      final result = await receivePort.first as List<String>;

      stopwatch.stop();
      print(
          '✅ [MAIN THREAD] Received result from Isolate in ${stopwatch.elapsedMilliseconds}ms. Main UI remained 100% unblocked!');

      return result;
    } finally {
      // ۶. پاکسازی همیشگی منابع پس از اتمام کار
      _activeIsolate = null;
      receivePort.close();
      print(
          '🧹 [MAIN THREAD] Isolate communication port closed & resources freed.');
    }
  }

  /// نقطه ورود ایزولیت (این تابع کاملاً در یک ترد جداگانه اجرا می‌شود)
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

  /// هسته اصلی محاسبات (شامل الگوریتم هندسی + هوش مصنوعی احتمالات)
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

  /// این تابع لیست حرکات هندسی و احتمالی پری‌موو را می‌گیرد
  /// و فقط آن‌هایی را برمی‌گرداند که حداقل در یک سناریو (یک حرکت ممکن حریف) از نظر قانونی قابل اجرا باشند.
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
      // ساخت یک نمونه شطرنج از وضعیت فعلی (نوبت حریف است)
      var chess = chess_lib.Chess.fromFEN(currentFen);

      // استخراج تمام حرکات قانونی حریف در این لحظه به صورت رشته SAN (مثل e4, Nf3)
      // استفاده از کستینگ امن به List<String> برای جلوگیری از خطاهای ناشناخته کتابخانه
      List<String> opponentMoves = List<String>.from(chess.moves());
      print(
          '[AI-INFO] Total opponent moves possible in this turn: ${opponentMoves.length}');

      // بررسی هر کدام از خانه‌های مقصدی که الگوریتم هندسی ما در مرحله قبل پیدا کرده است
      for (String target in pseudoLegalDestinations) {
        bool isPossibleInAnyScenario = false;

        // برای این خانه مقصد، تمام آینده‌های احتمالی (حرکات حریف) را شبیه‌سازی می‌کنیم
        for (String oppMove in opponentMoves) {
          // یک تخته مجازی برای شبیه‌سازی آینده می‌سازیم تا FEN اصلی خراب نشود
          var simulationBoard = chess_lib.Chess.fromFEN(currentFen);

          // ۱. حریف حرکتش را انجام می‌دهد (شبیه‌سازی آینده)
          bool oppMoveSuccess = simulationBoard.move(oppMove);
          if (!oppMoveSuccess) {
            print('[AI-WARNING] Failed to simulate opponent move: $oppMove');
            continue;
          }

          // ۲. حالا نوبت ماست. آیا در این وضعیتِ جدید، پری‌موو ما قانونی و ممکن است؟
          bool isValidPremove = false;
          try {
            isValidPremove = simulationBoard.move({
              'from': fromSquare,
              'to': target,
              'promotion': 'q', // ترفیع پیش‌فرض برای تست
            });
          } catch (e) {
            isValidPremove = false;
          }

          // اگر حتی در یک حرکتِ حریف، این پری‌موو ممکن باشد، یعنی شدنی است!
          if (isValidPremove) {
            isPossibleInAnyScenario = true;
            print(
                '[AI-MATCH] Target $target IS POSSIBLE if opponent plays: $oppMove');
            break; // پیدا کردن یک سناریوی موفق کافی است، نیازی به بررسی بقیه حرکات حریف نیست
          }
        }

        // اگر این حرکت در آینده شدنی است، آن را به لیست نهایی اضافه می‌کنیم
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
      // در صورت کرش کردن هوش مصنوعی، برای جلوگیری از قفل شدن بازی، لیست خام هندسی را برمی‌گردانیم
      return pseudoLegalDestinations;
    }

    print('[AI-END] Final approved targets: $trulyPossibleMoves');
    print('==================================================');
    return trulyPossibleMoves;
  }
}
