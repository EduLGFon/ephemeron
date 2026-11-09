# Principles

- The app and all of its features must be blazing fast.
- User experience is the most important thing in the thinking process, then
  optimization, then everything else.
- Battery usage must be extremely low: as little as possible.
- Updates should be optimistic: apply user mutations to local state/UI
  immediately and reconcile with the server in the background; never block the
  user on network I/O.
- Destructive updates must wait the 6s rule before applying (already
  implemented; keep in line for future updates).
