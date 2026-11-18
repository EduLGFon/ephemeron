# Principles

- App and features must be blazing fast.
- UX first, then optimization, then everything else.
- Battery extremely low.
- Optimistic updates: mutate local state/UI immediately, reconcile server in background; never block on network I/O.
- Destructive updates wait 6s rule (implemented; keep for future).
## UI performance rules

- Flat surfaces, tonal colour and 1px hairline borders. No blur, BackdropFilter, glassmorphism, ShaderMask, large layered shadows or ClipRRect on big subtrees. Static tiny gradients only.
- `const` constructors and small widgets; files ~150 lines soft, ~300 review. No Intrinsic* widgets, nested scrollables or per-frame whole-screen rebuilds.
- Watch the narrowest provider slice with `select`/family. A row change must not rebuild the list; Today filters tasks once per emission.
- Lists use `ListView.builder`/slivers, stable `ValueKey(id)` and `itemExtent`/`prototypeItem` when fixed.
- Wrap timer digits, rings, heatmaps and independently animating pieces in `RepaintBoundary`; use `AnimatedBuilder` with `child`.
- Animations 120-250 ms, transform/opacity only. Honor `MediaQuery.disableAnimations` and the persisted reduce-motion setting.
- Times, counters and tables use tabular figures. Custom visuals use `CustomPainter` or plain shapes; no image assets, Lottie or network fonts.
- 48dp touch targets on touch platforms; WCAG AA contrast; Semantics labels for icon-only controls; never colour alone for status.
- Web uses hash URLs (`/#/...`, go_router's default strategy; see `docs/PAGES_DEPLOY.md`) and keeps the initial bundle under the 2 MB gzip budget; no new heavy assets.
