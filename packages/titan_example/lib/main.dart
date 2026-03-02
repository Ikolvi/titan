import 'package:flutter/material.dart';
import 'package:titan_atlas/titan_atlas.dart';
import 'package:titan_bastion/titan_bastion.dart';

import 'pillars/quest_detail_pillar.dart';
import 'pillars/quest_list_pillar.dart';
import 'pillars/questboard_pillar.dart';
import 'screens/about_screen.dart';
import 'screens/enterprise_demo_screen.dart';
import 'screens/hero_profile_screen.dart';
import 'screens/hero_registration_screen.dart';
import 'screens/quest_detail_screen.dart';
import 'screens/quest_list_screen.dart';

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
//   Bulwark                    -- Circuit breaker
//   Saga                       -- Multi-step workflows
//   Volley                     -- Batch async operations
//   Sigil                      -- Feature flags
//   Aegis                      -- Retry with backoff
//   Annals                     -- Audit trail
//   Tether                     -- Request-response channels
//   Core extensions            -- toggle, increment, add, removeWhere
//   onInitAsync                -- Async Pillar initialization
//
// ---------------------------------------------------------------------------

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up Chronicle logging
  Chronicle.level = LogLevel.debug;

  // Set up Vigil error tracking with console output
  Vigil.addHandler(ConsoleErrorHandler());

  // Create Atlas router
  final atlas = Atlas(
    passages: [
      // Sanctum: persistent bottom nav shell
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
    observers: [HeraldAtlasObserver()],
  );

  runApp(
    // Lens -- debug overlay (disable in production)
    Lens(
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
                : '/enterprise',
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
        ],
      ),
    );
  }
}
