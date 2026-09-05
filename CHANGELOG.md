## 1.0.1

* Relaxed `chess` dependency constraints to `>=0.7.0 <0.9.0` to resolve version conflicts with other packages (like `flutter_chess_board`).

## 1.0.0

* Initial release of the `chess_premove` package.
* Added `PremoveIntelligence` class with `calculatePremovesAsync` method for high-performance premove validation.
* Implemented background `Isolate` processing to completely eliminate UI freezing and dropped frames.
* Integrated smart Isolate cancellation (`isolate.kill()`) to prevent race conditions during rapid user clicks.
* Removed Flutter framework dependencies to establish a "Pure Dart Package" architecture.
* Ensured maximum cross-platform compatibility (Mobile, Web, Desktop, and Server).
* Fully Null Safe and optimized for Dart 3.12 and above.