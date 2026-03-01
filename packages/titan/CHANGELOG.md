## 0.0.2

### Added
- **`Titan.forge()`** — Register a Pillar by its runtime type for dynamic registration (e.g., Atlas DI integration)
- **`Titan.removeByType()`** — Remove a Pillar by runtime Type without needing a generic parameter

## 0.0.1

### Added
- **Pillar** — Structured state module with lifecycle (`onInit`, `onDispose`)
- **Core** — Fine-grained reactive mutable state (`core(0)` / `Core(0)`)
- **Derived** — Auto-computed values from Cores, cached and lazy (`derived(() => ...)` / `Derived(() => ...)`)
- **Strike** — Batched state mutations (`strike(() { ... })`)
- **Watch** — Managed reactive side effects (`watch(() { ... })`)
- **Titan** — Global Pillar registry (`Titan.put()`, `Titan.get()`, `Titan.lazy()`)
- **TitanObserver** (Oracle) — Global state change observer
- **TitanMiddleware** (Aegis) — State change interceptor
- **TitanContainer** (Vault) — Hierarchical DI container
- **TitanModule** (Forge) — Dependency assembly modules
- **AsyncValue** (Ether) — Loading / error / data async wrapper
- **TitanConfig** (Edict) — Global configuration
