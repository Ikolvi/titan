/// Colossus — Enterprise-grade performance monitoring for Titan.
///
/// Colossus provides real-time performance metrics, leak detection,
/// page load timing, and rebuild tracking that integrates seamlessly
/// with the Titan ecosystem.
///
/// ## Quick Start
///
/// ```dart
/// // In your app startup (debug mode only):
/// Colossus.init();
///
/// // Wrap widgets to track rebuilds:
/// Echo(label: 'MyWidget', child: MyWidget());
///
/// // Auto-track page loads via Atlas:
/// Atlas(
///   observers: [ColossusAtlasObserver()],
///   passages: [...],
/// );
/// ```
///
/// ## Features
///
/// - **Pulse**: Frame rendering metrics (FPS, jank, build/raster times)
/// - **Stride**: Page load timing with time-to-first-paint
/// - **Vessel**: Memory monitoring and leak detection
/// - **Echo**: Widget rebuild tracking
/// - **Tremor**: Configurable performance alerts via Herald
/// - **Decree**: Aggregated performance reports
/// - **Inscribe**: Export reports as Markdown, JSON, or HTML
/// - **Shade**: Gesture recording & macro replay
/// - **Lens Integration**: Auto-registered "Perf" and "Shade" tabs in the Lens overlay
library;

// Metrics
export 'src/metrics/mark.dart';
export 'src/metrics/decree.dart';

// Alerts
export 'src/alerts/tremor.dart';

// Monitors
export 'src/monitors/pulse.dart';
export 'src/monitors/stride.dart';
export 'src/monitors/vessel.dart';

// Widgets
export 'src/widgets/echo.dart';
export 'src/widgets/shade_listener.dart';
export 'src/widgets/shade_text_controller.dart';

// Export
export 'src/export/inscribe.dart';
export 'src/export/inscribe_io.dart';

// Recording
export 'src/recording/imprint.dart';
export 'src/recording/phantom.dart';
export 'src/recording/shade.dart';
export 'src/recording/shade_vault.dart';

// Core
export 'src/colossus.dart';

// Integrations
export 'src/integration/colossus_atlas_observer.dart';
export 'src/integration/colossus_lens_tab.dart';
export 'src/integration/lens.dart';
export 'src/integration/shade_lens_tab.dart';
