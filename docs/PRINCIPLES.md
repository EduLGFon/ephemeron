# Principles

- App and features must be blazing fast.
- UX first, then optimization, then everything else.
- Battery extremely low.
- Optimistic updates: mutate local state/UI immediately, reconcile server in background; never block on network I/O.
- Destructive updates wait 6s rule (implemented; keep for future).