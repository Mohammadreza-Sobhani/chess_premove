# Chess Premove Intelligence ♟️⚡

A high-performance, asynchronous chess premove intelligence and validation package for Dart and Flutter. 

This package completely eliminates Race Conditions and UI freezing (dropped frames) when users rapidly click on chess pieces to register premoves during their opponent's turn.

## ✨ Features

*   **Zero UI Blocking:** Heavy chess move calculations are offloaded to a background `Isolate`.
*   **Smart Cancellation:** If a user clicks multiple pieces rapidly, previous calculations are instantly killed (`isolate.kill()`) to save RAM and CPU.
*   **100% Pure Dart:** No dependencies on the Flutter framework. Works perfectly on Mobile, Web, Desktop, and Server/Backend.
*   **Intelligent Filtering:** Doesn't just find geometric moves; it simulates the opponent's possible future moves to ensure the premove is actually legal in at least one scenario.

## 🚀 Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  chess_premove: ^1.0.0

```

Import the package in your Dart code:

```dart
import 'package:chess_premove/chess_premove.dart';

```

## 💻 Usage

Simply pass your current FEN string and the algebraic notation of the square the user tapped. The package will return a `List<String>` of mathematically and legally possible premove destinations.

```dart
import 'package:chess_premove/chess_premove.dart';

void handlePremoveRequest() async {
  String currentFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  String tappedSquare = 'd8';

  try {
    // Calculates valid premove squares entirely in the background!
    List<String> validPremoves = await PremoveIntelligence.calculatePremovesAsync(
      currentFen,
      tappedSquare,
      intelligence: true, // Set to false if you only want geometric pseudo-legal moves
    );

    print('Valid premove destinations: $validPremoves');
  } catch (e) {
    if (e is InvalidPremoveTurnException) {
      print('It is your turn! You cannot register a premove right now.');
    } else {
      print('Error calculating premoves: $e');
    }
  }
}

```

## 🧠 Under the Hood

When `calculatePremovesAsync` is called:

1. An O(1) synchronous check verifies if the tapped piece belongs to the waiting player.
2. A background `Isolate` is spawned.
3. If the function is called again before the first finishes, the previous `Isolate` is instantly terminated using `isolate.kill()`, freeing RAM and CPU.
4. The result is safely passed back to your Main Thread.

---

### 👨‍💻 About the Author

**Made with ❤️ in Iran by Mohammadreza Sobhani**

This package was designed to bring Enterprise-level architecture and multi-threading stability to chess applications across the Dart ecosystem.