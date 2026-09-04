# Chess Premove Intelligence ♟️⚡

[![Pub Version](https://img.shields.io/pub/v/chess_premove?color=blue)](https://pub.dev/packages/chess_premove)
[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](https://opensource.org/licenses/MIT)

A high-performance, asynchronous chess premove intelligence and validation package for Dart and Flutter. 

This package completely eliminates Race Conditions and UI freezing (dropped frames) when users rapidly click on chess pieces to register premoves during their opponent's turn.

---

## 🚀 See it in Action

Provide your users with a buttery-smooth chess experience. Register premoves during the opponent's turn without ever blocking the main thread.

<p align="center">
  <img src="https://raw.githubusercontent.com/Mohammadreza-Sobhani/chess_premove/main/doc/premove_in_action.gif" alt="Premove In Action" width="600"/>
</p>

### 🧠 Smart Simulation Engine
Instead of just returning basic geometric moves, the **Intelligent Filtering** simulates all possible future opponent moves to ensure a premove target is *actually* achievable in the next turn.

<p align="center">
  <img src="https://raw.githubusercontent.com/Mohammadreza-Sobhani/chess_premove/main/doc/premove_logic_result.png" alt="Premove Logic Result" width="600"/>
</p>

---

## ✨ Features

*   **Zero UI Blocking:** Heavy chess move calculations are offloaded to a background `Isolate` thread.
*   **Smart Cancellation:** If a user clicks multiple pieces rapidly, previous calculations are instantly killed (`isolate.kill()`) to save RAM and CPU.
*   **Smart Web Support:** Seamlessly falls back to optimized main-thread execution on the Web (where Isolates are unsupported) with built-in anti-spam throttling.
*   **100% Pure Dart:** No dependencies on the Flutter framework. Works perfectly on Mobile, Web, Desktop, and Server/Backend.
*   **Intelligent Filtering:** Doesn't just find geometric moves; it simulates the opponent's possible future moves to ensure the premove is actually legal in at least one scenario.

## 📦 Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  chess_premove: ^1.0.0
```

Then, run:

```bash
dart pub get
```

## 💻 Usage

Using `chess_premove` is incredibly simple. Just pass the current FEN and the square the user tapped.

### Advanced Strict Filtering (Recommended)

When `intelligence` is set to `true`, the package runs a deep simulation against all possible opponent responses to ensure the premove is strategically valid.

```dart
import 'package:chess_premove/chess_premove.dart';

void main() async {
  // 1. Current game state (White's turn)
  String currentFen = 'rnb1kbnr/ppp1pppp/8/3q4/8/8/PPPP1PPP/RNBQKBNR w KQkq - 0 3';
  
  // 2. The square the user tapped to register a premove (Black Queen)
  String tappedSquare = 'd5';

  try {
    // 3. Smart background calculation
    List<String> validPremoves = await PremoveIntelligence.calculatePremovesAsync(
      currentFen,
      tappedSquare,
      intelligence: true, // Set to false if you only want geometric pseudo-legal moves
    );

    print('✅ Final approved targets for $tappedSquare:');
    print(validPremoves); 
    // Output: [d8, d7, c6, d6, e6, a5, b5, c5, e5, f5, g5, h5, c4, d4, e4, b3, d3, f3, a2, d2, g2, h1]

  } catch (e) {
    if (e is InvalidPremoveTurnException) {
      print('❌ Error: It is your turn! You cannot register a premove right now.');
    } else {
      print('❌ Error calculating premoves: $e');
    }
  }
}
```

## 🧠 Under the Hood

When `calculatePremovesAsync` is called:

1. An O(1) synchronous check verifies if the tapped piece belongs to the waiting player.
2. A background `Isolate` is spawned (on Native platforms).
3. If the function is called again before the first finishes, the previous `Isolate` is instantly terminated using `isolate.kill()`, freeing RAM and CPU.
4. The result is safely passed back to your Main Thread.

## 🛡️ Exceptions

The package throws specific, catchable exceptions to help you manage state in your UI:

* **`InvalidPremoveTurnException`**: Thrown if a user tries to calculate a premove when it is currently their own turn.
* **`PremoveSpamException`**: Thrown on Web platforms if the user taps too rapidly (< 200ms) to prevent freezing the single-threaded JavaScript environment.

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/Mohammadreza-Sobhani/chess_premove/issues).

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/Mohammadreza-Sobhani/chess_premove/blob/main/LICENSE) file for details.

---

### 👨‍💻 About the Author

**Made with ❤️ in Iran by Mohammadreza Sobhani**

This package was designed to bring Enterprise-level architecture and multi-threading stability to chess applications across the Dart ecosystem.