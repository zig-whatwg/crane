# Testing: An engine's trace on stdout and the adapter's on stderr cut each other's lines in one file

**Date**: 2026-11-14
**Lesson**: Send a process's stdout and stderr to separate files when both carry lines a script will parse; `> log 2>&1` interleaves the two streams in the middle of a line and silently loses records.

**Why**: V8 prints `--trace-gc-nvp` with its own buffered stdout writes; Crane's adapter and gc_bench write stderr unbuffered. One collection's JSON line is several kilobytes, written in pieces, and a short stderr line emitted meanwhile lands inside it. Both lines are then unparseable, and a parser that skips bad lines reports fewer collections than ran.

**What Happened**: Lane dm1's first summary of a gc_bench drop loop paired the k-th collection of V8's trace with the k-th of its own trace lines and printed figures that did not belong together: "told 20.7 MB" beside "counter 0.0 MB". The run had 4 full collections; the parser found 1 complete JSON line and 2 of 4 prologue lines. `sed -n 4p` showed a trace line starting in the middle of the JSON. Writing stdout to `<log>.v8` and stderr to `<log>`, and pairing by the collection number each line carries, fixed it. Lane v8up's page driver already kept the two in stdout.txt and stderr.txt.

**Fix**:
1. `cmd > run.v8 2> run.log` for anything parsed; merge the two in the reader, by a key each line carries (a sequence number), never by position.
2. Count the records the parser found against a count the process reports itself (gc_bench's `full_gc_count`), and fail the summary when they differ.

**Takeaway**: **Two writers, one file, no line discipline: keep parsed streams apart and pair records by an explicit key, and check the parsed count against the process's own.**
