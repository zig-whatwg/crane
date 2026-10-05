# Debugging: The WPT runner's stderr is positional - redirected to a file it overwrites what came before; pipe it

**Date**: 2026-10-05
**Lesson**: `wpt_runner ... > run.log 2>&1` loses output: the runner writes
its report through a buffered, positional file writer (Zig 0.16
`File.Writer` on a seekable file writes at its own offset), so it overwrites
debug prints, log lines and DebugAllocator `leaked:` lines that went to the
same file before it. `wpt_runner ... 2>&1 | cat > run.log` keeps everything.

**Why**: a pipe is not seekable, so the writer streams; a regular file is,
so it writes at the offset it tracks itself, from 0.

**What Happened**: a debug print at process start and in an element's DOM
callback never appeared in run.log; `leaked:` counts read 0, 19, 35 for
the same tree; the log started "Founderror(DebugAllocator)..." - the
runner's "Found N test files" written over the leak report. Piped through
`cat`, every print and leak line was there (crane-measure.sh sweep already
pipes its runs).

**Fix**: pipe the runner's output (`2>&1 | cat > file`) in every scratch
script whose log is read for prints or leak counts.

**Takeaway**: **Never redirect the runner straight into a file you will
grep: pipe it through `cat`. A log line that "never prints" may have been
overwritten.**
