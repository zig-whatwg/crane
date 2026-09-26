# Debugging: Redirect the runner's output into a pipe, never a file

**Date**: 2026-09-24
**Lesson**: `wpt_runner ... > run.log 2>&1` loses every engine `std.log` line
and every `std.debug.print` - even a raw `write(2, ...)`. The same command
piped (`2>&1 | cat > run.log`) keeps them all.

**Why**: the runner writes its report through a 256 KB buffered
`std.Io.File` writer. On a regular file that writer runs in positional mode:
it `pwrite`s from its own offset, starting at 0, so when it flushes it
overwrites whatever else reached the file first - the engine's log lines
included. A pipe cannot be written positionally, so the writer streams and
every line survives.

**What Happened**: chasing the moving-between-documents timeouts, four
rounds of instrumentation "never ran": warn logs, then `std.debug.print`,
then raw writes, all absent - while lldb showed the instrumented function
being hit. The silence was the log file, not the code. Piped, the first run
showed every message being posted and delivered.

**Fix**: `./zig-out/bin/wpt_runner <file> --wpt-root=tests/wpt 2>&1 | cat > log`.
The same is why no `(warn)` line from the engine has ever appeared in a
runner log that went to a file.

**Takeaway**: **Before concluding instrumentation did not run, pipe the
output.** An absent line in a redirected log proves nothing.
