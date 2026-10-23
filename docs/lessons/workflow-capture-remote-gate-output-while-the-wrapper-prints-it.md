# Workflow: Capture remote gate output while the wrapper prints it

**Date**: 2026-10-23
**Lesson**: Pipe crane-remote's terminal output into a lane log with pipefail; its remote log is removed after successful delivery.

**Why**: A remote log is retained for a dropped connection, but a normal completion prints and deletes it. Waiting until the process ends before copying that path can lose the file needed for a gate receipt. Positional output can also overwrite earlier text when the producer writes directly to the wrapper's regular log file.

**What Happened**: Row 119's focused Q71 RED printed four failures and exited normally. A subsequent SCP of the advertised remote log failed because crane-remote had already removed it. The terminal transcript retained the evidence; the test was not rerun just to recreate a log. The later full native run retained its summary but overwrote initial lint count lines.

**Fix**: Use `set -o pipefail` inside the remote script and pipe the build's combined output through `cat`; outside the wrapper, use pipefail and `tee` to capture its delivery in lane scratch. Read counts and failure lines from that log. Recover a missing lint-only count with the cached lint step, not another native suite. If the connection drops, inspect the advertised remote log and existing job instead of starting another build.

**Takeaway**: **Capture a successful delivery of output locally; the remote copy is only a connection-loss fallback.**
