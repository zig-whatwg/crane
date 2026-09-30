# Debugging: The runner writes its log positionally - trace through a pipe

**Date**: 2026-09-30
**Lesson**: `wpt_runner` writes its own output through a Zig `File.Writer`, which
on a regular file writes POSITIONALLY (pwrite at the offset it tracks). Anything
else written to the same file - `std.debug.print`, `std.log`, a raw `write(2)`
from a scratch trace - lands at the shared offset and is overwritten by the
runner's next write. Redirect the runner through a pipe (`2>&1 | cat > log`),
where positional writes are impossible, and every line survives.

**Why**: `> log 2>&1` gives stdout and stderr one open file description. A
streaming writer appends after the other writer's bytes; a positional one
writes where it thinks the file ends, on top of them.

**What Happened**: chasing `xhr/xhr-timeout-longtask.any.js`, five scratch trace
builds "printed nothing" or printed lines cut mid-word ("before(ou") and
interleaved with the runner's report ("Reached unreaFLTRACE call"). The env var
was set (`ps eww` showed it), the strings were in the binary, the code ran - its
bytes were simply overwritten. Piping the runner's output through `cat` showed
every trace line at once, and the cause fell out of the first run.

**Fix**: in scratch scripts, `./zig-out/bin/wpt_runner ... 2>&1 | cat > "$o/stdout.log"`
and `rc=${PIPESTATUS[0]}`. Prefer short, one-line traces written with a single
`write(2)` (format into a stack buffer first) so concurrent writers cannot split
them.

**Takeaway**: **If a trace in the runner's log is missing or cut, suspect the
log, not the code: the runner overwrites what it did not write. Pipe it.**
