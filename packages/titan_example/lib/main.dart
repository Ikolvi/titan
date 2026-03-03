import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:titan_argus/titan_argus.dart';
import 'package:titan_bastion/titan_bastion.dart';
import 'package:titan_colossus/titan_colossus.dart';

import 'pillars/auth_pillar.dart';
import 'pillars/quest_detail_pillar.dart';
import 'pillars/quest_list_pillar.dart';
import 'pillars/questboard_pillar.dart';
import 'screens/about_screen.dart';
import 'screens/enterprise_demo_screen.dart';
import 'screens/hero_profile_screen.dart';
import 'screens/hero_registration_screen.dart';
import 'screens/login_screen.dart';
import 'screens/quest_detail_screen.dart';
import 'screens/quest_list_screen.dart';
import 'screens/shade_demo_screen.dart';
import 'screens/spark_demo_screen.dart';

// ---------------------------------------------------------------------------
// Questboard -- The Titan Example App
// ---------------------------------------------------------------------------
//
// This is the Questboard app from The Chronicles of Titan story tutorial.
// It demonstrates every Titan feature through a hero quest-tracking theme.
//
// Features demonstrated:
//   Pillar, Core, Derived     -- Reactive state modules
//   Vestige, Beacon           -- Flutter widget integration
//   Atlas, Passage, Sanctum   -- Declarative routing
//   Herald                     -- Cross-Pillar event bus
//   Vigil, Chronicle          -- Error tracking and logging
//   Epoch                      -- Undo/redo (hero name)
//   Scroll, ScrollGroup       -- Form validation (registration)
//   Codex                      -- Pagination (quest list)
//   Quarry                     -- Data fetching with SWR (quest detail)
//   Confluence                 -- Multi-Pillar consumers
//   Lens                       -- Debug overlay
//   Loom                       -- Finite state machine
//   Portcullis                 -- Circuit breaker
//   Saga                       -- Multi-step workflows
//   Volley                     -- Batch async operations
//   Sigil                      -- Feature flags
//   Aegis                      -- Retry with backoff
//   Annals                     -- Audit trail
//   Tether                     -- Request-response channels
//   Core extensions            -- toggle, increment, add, removeWhere
//   onInitAsync                -- Async Pillar initialization
//   Colossus                   -- Performance monitoring (Pulse, Vessel, Stride)
//   Shade                      -- Gesture recording & macro replay
//   Phantom                    -- Automated gesture replay engine
//   CoreRefresh                -- Reactive Sentinel re-evaluation on auth change
//
// ---------------------------------------------------------------------------

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up Chronicle logging
  Chronicle.level = LogLevel.debug;

  // Set up Vigil error tracking with console output
  Vigil.addHandler(ConsoleErrorHandler());

  // Initialize Colossus performance monitoring with session persistence
  final shadeDir = '${Directory.systemTemp.path}/questboard_shade';
  final exportDir = _getExportDirectory();
  Colossus.init(
    tremors: [Tremor.fps(), Tremor.jankRate(), Tremor.leaks()],
    enableLensTab: true,
    enableChronicle: true,
    shadeStoragePath: shadeDir,
    exportDirectory: exportDir,
  );

  // Share exported reports via the system share sheet.
  // This works on all platforms without storage permissions.
  Colossus.instance.onExport = (paths) {
    SharePlus.instance.share(
      ShareParams(files: paths.map((p) => XFile(p)).toList()),
    );
  };

  // Wire up route-aware recording — Shade captures the current route
  // so Phantom can verify the correct page before replay
  Colossus.instance.shade.getCurrentRoute = () {
    try {
      return Atlas.current.path;
    } catch (_) {
      return null;
    }
  };

  // Check for auto-replay on startup (replays saved session if configured)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Colossus.instance.checkAutoReplay();
  });

  // Register AuthPillar globally for Sentinel access during Atlas construction
  Titan.put(AuthPillar());
  final authPillar = Titan.get<AuthPillar>();

  // Argus.guard() — combines authGuard + guestOnly + CoreRefresh
  // in a single call for fully reactive auth routing
  final garrisonAuth = authPillar.guard(
    loginPath: '/login',
    homePath: '/',
    publicPaths: {'/about'},
    guestPaths: {'/login'},
  );

  // Create Atlas router with reactive auth routing
  final atlas = Atlas(
    passages: [
      // Login screen — outside Sanctum shell, accessible when unauthenticated
      Passage(
        '/login',
        (waypoint) => LoginScreen(waypoint: waypoint),
        name: 'login',
      ),

      // Sanctum: persistent bottom nav shell (protected by Sentinel)
      Sanctum(
        shell: (child) => _QuestboardShell(child: child),
        passages: [
          Passage('/', (_) => const QuestListScreen(), name: 'quests'),
          Passage('/hero', (_) => const HeroProfileScreen(), name: 'hero'),
          Passage(
            '/enterprise',
            (_) => const EnterpriseDemoScreen(),
            name: 'enterprise',
          ),
          Passage('/spark', (_) => const SparkDemoScreen(), name: 'spark'),
          Passage('/shade', (_) => const ShadeDemoScreen(), name: 'shade'),
        ],
      ),

      // Standalone pages outside the shell
      Passage(
        '/quest/:id',
        (waypoint) => QuestDetailScreen(questId: waypoint.runes['id'] ?? ''),
        shift: Shift.slideUp(),
        name: 'quest-detail',
      ),
      Passage(
        '/register',
        (_) => const HeroRegistrationScreen(),
        shift: Shift.slide(),
        name: 'register',
      ),
      Passage(
        '/about',
        (_) => const AboutScreen(),
        shift: Shift.fade(),
        name: 'about',
      ),
    ],
    observers: [HeraldAtlasObserver(), ColossusAtlasObserver()],
    sentinels: garrisonAuth.sentinels,
    refreshListenable: garrisonAuth.refresh,
  );

  runApp(
    // ShadeListener -- captures all gestures for recording
    ShadeListener(
      shade: Colossus.instance.shade,
      // Lens -- debug overlay (disable in production)
      child: Lens(
        enabled: true,
        child: Beacon(
          pillars: [
            QuestboardPillar.new,
            QuestListPillar.new,
            QuestDetailPillar.new,
          ],
          child: MaterialApp.router(
            title: 'Questboard',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorSchemeSeed: Colors.deepPurple,
              useMaterial3: true,
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              colorSchemeSeed: Colors.deepPurple,
              useMaterial3: true,
              brightness: Brightness.dark,
            ),
            routerConfig: atlas.config,
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Questboard Shell -- Sanctum persistent layout
// ---------------------------------------------------------------------------

class _QuestboardShell extends StatelessWidget {
  final Widget child;
  const _QuestboardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final path = Atlas.current.path;
    final index = path == '/hero'
        ? 1
        : path == '/enterprise'
        ? 2
        : path == '/spark'
        ? 3
        : path == '/shade'
        ? 4
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.shield),
            SizedBox(width: 8),
            Text('Questboard'),
          ],
        ),
        actions: [
          // Sign out button — CoreRefresh auto-redirects to /login
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Titan.get<AuthPillar>().signOut(),
            tooltip: 'Sign Out',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.atlas.to('/about'),
            tooltip: 'About',
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          context.atlas.go(
            i == 0
                ? '/'
                : i == 1
                ? '/hero'
                : i == 2
                ? '/enterprise'
                : i == 3
                ? '/spark'
                : '/shade',
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Quests',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Hero',
          ),
          NavigationDestination(
            icon: Icon(Icons.business_center_outlined),
            selectedIcon: Icon(Icons.business_center),
            label: 'Enterprise',
          ),
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt),
            label: 'Spark',
          ),
          NavigationDestination(
            icon: Icon(Icons.fiber_smart_record_outlined),
            selectedIcon: Icon(Icons.fiber_smart_record),
            label: 'Shade',
          ),
        ],
      ),
    );
  }
}

/// Returns a user-accessible directory for exporting reports.
///
/// On macOS/Linux: `~/Downloads/colossus_reports`
/// On other platforms: falls back to system temp.
String _getExportDirectory() {
  try {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null) {
      final downloads = '$home/Downloads/colossus_reports';
      Directory(downloads).createSync(recursive: true);
      return downloads;
    }
  } catch (_) {
    // Fall back to temp
  }
  return '${Directory.systemTemp.path}/colossus_reports';
}
