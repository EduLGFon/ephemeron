# Principles

Project-specific UI/performance rules. Generic UX/perf baseline is global (`~/.config/opencode/AGENTS.md`); see `ARCHITECTURE.md` for budgets.

## Numeric budgets (ARCHITECTURE.md)
- Cold start <600 ms, warm <200 ms, frame <16 ms, idle RAM <150 MB, background CPU zero, battery <1%/day, APK <15 MB/ABI, web initial <2 MB gzip, any screen query <10 ms for 50k rows.

## Flutter/UI rules
- Flat surfaces, tonal colour, 1px hairlines. No blur, BackdropFilter, glassmorphism, ShaderMask, large layered shadows, or large ClipRRect. Static tiny gradients only.
- const widgets and small widgets; files ~150 lines soft, ~300 review. No Intrinsic* widgets, nested scrollables, or per-frame whole-screen rebuilds.
- Narrowest provider slice via `select`/`family`; a row change must not rebuild the list.
- `ListView.builder`/slivers with stable `ValueKey(id)` and `itemExtent`/`prototypeItem` when fixed.
- `RepaintBoundary` for timer digits, rings, heatmaps, independently animating pieces; `AnimatedBuilder` with child.
- Animations 120-250 ms, transform/opacity only. Honor reduced motion.
- Tabular figures; `CustomPainter` or plain shapes. No image assets, Lottie, or network fonts.
- 48dp touch targets; WCAG AA; Semantics for icon-only; never colour alone for status.
- Primary actions bottom-aligned for single-hand use.
- Web uses hash URLs and keeps initial bundle under 2 MB gzip; no heavy assets.
