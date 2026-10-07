# Placebo Clicker

An external autoclicker for Minecraft Bedrock, written in Ada. No DLL injection, no signature scanning, no per-update offsets. It issues clicks through the standard OS input path while the game window is focused, which the game accepts as ordinary input.

Small footprint by design: approximately 500 KB on disk, under 2 MB private working set, and effectively zero CPU/GPU usage while idle (event-driven repaints, no render loop).

## How It Clicks

- A low-level mouse hook (`WH_MOUSE_LL`) tracks the true physical button state.
- Every synthetic click carries a unique tag in `dwExtraInfo`. The hook ignores tagged events, so the engine can never mistake its own output for user input (which would otherwise toggle its own UI in a feedback loop).
- The click engine runs on a dedicated task at 1 ms resolution: uniform CPS selection between configurable min/max, flat timing, and explicit press/release scheduling.
- Clicks fire only while the Minecraft window holds the foreground. Tabbing out mid-hold releases immediately and resumes on return.

## Formal Verification

All decision logic lives in `src/spark/clicker_core.*` under full `SPARK_Mode` and is proven with GNATprove at level 4 (10 s timeout, CVC5/Z3/Alt-Ergo):

| Category | Checks | Unproved |
|---|---|---|
| Run-time checks | 26 | 0 |
| Functional contracts | 7 | 0 |
| Termination | 6 | 0 |

Notable properties:

- `Pick_Cps` provably returns a value within `Min_Cps .. Max_Cps`. It uses modular arithmetic over raw RNG bits; an earlier rounding-based version could select one past maximum and silently kill the engine, which is exactly the bug class the proofs exist to catch.
- `Step` provably never issues a press while a button is already held, and always issues a release when the input gate closes.
- `Hold_For` scales the press duration with the interval, keeping 60 CPS reachable (a fixed 25 ms hold caps throughput at roughly 40 CPS).

System-call wrappers (input injection, hooks, window management) are necessarily outside the proven subset. This matches the standard pattern for verified Windows software: every decision is proven, only the thin OS boundary is not.

## Building

Requirements: GNAT 14 and GPRbuild (the Alire-provided toolchains are the simplest source).

```cmd
build.cmd
```

The executable is produced at `bin/placebo.exe`. Configuration persists automatically to `placebo.ini` beside the executable. To re-run the proof (requires GNATprove 14.x):

```cmd
gnatprove -P ada_clicker.gpr -j0
```

## Project Layout

- `src/spark/` — proven core: timing math, press scheduler, CPS selection
- `src/os/` — hand-written Win32 bindings, click-engine task, mouse hook
- `src/ui/` — dependency-free, owner-drawn animated Win32 interface
- `src/main.adb` — entry point
- `assets/` — application icon and logo sources

## License

MIT. See `LICENSE` for details.
