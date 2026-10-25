# Workflow: An Empty Bash Array Can Stop a Measurement Launcher

**Date**: 2026-10-24
**Lesson**: Under macOS's older Bash, an empty optional argument array can be treated as unset by `set -u`.

**Why**: A scratch sweep launcher initialized `extra=()` and expanded `"${extra[@]}"` when no optional flags were needed. The shell rejected that expansion before starting crane-measure or the runner, so the tmux launch itself was not evidence that the measurement began.

**What Happened**: Row117's first redelivery launcher exited1 with `extra[@]: unbound variable`. Its first ten-minute progress receipt showed zero source journals, no live process, and no measurement tokens. The failed attempt and exit log were preserved.

**Fix**: Build one argument array that always contains the required `--wpt-root` option, then append `--verbose` only when needed. Verify actual runner startup once after launching, then observe the mandated sweep polling interval. Keep shell-only failures separate from completed measurement data; no source, test list, order or frozen executable changed for the restart.

**Takeaway**: **A successful tmux launch does not prove a runner started. Verify the runner banner and selected source count, and make optional arguments safe for the host shell.**
