# Workflow: Pair routing does not export the pair environment

**Date**: 2026-11-01
**Lesson**: Check the environment of each pool command separately; choosing a pair's host does not imply that the command exports its pair ID.

**Why**: `crane-pool.sh wpt --pair` both selects the pair's host and exports `CRANE_POOL_PAIR`. Its `on --pair` light-command path selects that host but does not export the variable. A new shell therefore cannot rely on the environment of the earlier WPT launch.

**What Happened**: Row131's full BASE/TIP comparison started correctly in one remote tmux session. Its separately launched startup check required the explicit pair environment before reading the group logs. Because the light command omitted the export, that check refused before observing either side. The sweeps continued; the failed check was not evidence that they had failed.

**Fix**:

1. Put `export CRANE_POOL_PAIR=<the-pair-id>` inside every light command whose reader requires it. Keep the actual group-log comparison; the export is not proof that a sweep joined the group.
2. Check the complete command through the applicable wrapper during preparation, including the environment it creates, rather than checking only the remote reader.
3. Preserve an original failed observation and ask for the permitted recovery. Q89 authorized one corrected read with distinct receipt names and required that the failed preflight remain recorded as failed.
4. Keep the launched remote packet unchanged. A corrected observation does not justify restarting a measurement, overwriting its receipts, or relaxing its result checks.

**Takeaway**: **Host routing and process environment are separate contracts; verify both before interpreting a measurement.**
