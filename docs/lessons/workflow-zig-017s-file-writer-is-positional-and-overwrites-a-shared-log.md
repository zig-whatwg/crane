# Workflow: Zig 0.17's `File.writer` is positional, and overwrites a log it shares

**Date**: 2026-11-01
**Lesson**: `std.Io.File.stdout().writer(io, &buf)` writes at file offsets it tracks itself, starting at 0, so a tool whose stdout is redirected into a log that other processes also write to overwrites their lines; `writerStreaming` appends like a plain `write`.

**Why**: in Zig 0.17 a `File.Writer` made by `writer()` is in positional mode: each flush is a `pwrite` at the writer's own position. When stdout is a terminal or a pipe that does not matter. When stdout is a regular file opened by the shell (`> log 2>&1`) and shared with other writers - the pool's `crane-measure.sh` printing its `holds X of N` line first, `/usr/bin/time -l` writing its report to the same file at exit - the tool writes from offset 0 over whatever was there, and the others write over the tool.

**What Happened**: lane tlaunch1's test launcher ran under `/usr/bin/time -l ~/crane-measure.sh run ... > $R/<label>.log 2>&1`. Every log came back 848 bytes: the launcher's first line cut off mid-sentence (`batch 10 ->`) and then `time`'s report, with the `holds` line and the launcher's summary gone. The runs themselves were fine - the result files (written separately) held all 640 results - so the first reading was "the launcher died after its header", which it had not.

**Fix**: `var stdout_writer = std.Io.File.stdout().writerStreaming(io, &stdout_buf);` for any tool whose output may be redirected into a shared file (tools/test_launcher/main.zig). A tool that owns its output file alone may keep `writer()`.

**Takeaway**: **For stdout in Zig 0.17, use `writerStreaming`: the positional `writer()` turns a shared log into an overwrite, and the damaged log looks like a crash.**
