# Testing: A Launcher Path Is Not a Process Identity

**Date**: 2026-10-29
**Lesson**: Verify the executable that a launcher actually runs before using its path as a process identity.

**Why**: A launcher can replace itself with another executable. Resolving a symlink or reading `sys.executable` does not prove what the process table will show after that replacement.

**What Happened**: A measurement watcher started through Homebrew's Python 3.14 launcher. The watcher reported readiness, but its strict argv check rejected it: the launcher had executed the framework's `Python.app/Contents/MacOS/Python` binary. The failure happened before the remote launch, so no test observation existed.

**Fix**: A small local probe recorded the requested and observed executable paths. Launching the observed binary directly made the complete argv match. Pin that binary's bytes and keep the exact PID, arguments, plan, stop path and scheduling checks. Preserve the original failed attempt, prove no observation occurred, and obtain the required recovery authorization before making one new launch.

**Takeaway**: **Bind identity to the measured executable; do not relax identity checks to accommodate an unverified launcher.**
