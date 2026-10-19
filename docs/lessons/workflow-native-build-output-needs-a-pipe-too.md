# Workflow: Native Build Output Needs a Pipe Too

**Date**: 2026-10-18
**Lesson**: Pipe native build output through a streaming consumer when several Zig tools share a redirected log.

**Why**: Zig 0.16's `std.Io.File.writer` starts with positional writes. Crane's lint tools use it on stdout. When stdout is a regular file, a later tool can write over the beginning of an earlier command's output.

**What Happened**: One remote job ran two native test commands and then built the WPT runner. The second command's lint output replaced the first command's `Build Summary` at the beginning of the shared log, leaving only the detailed passing-test fragment. The job's sequential progress proved the first command succeeded, but could not recover its missing summary text.

**Fix**: Use `set -o pipefail` and pipe each build or native-test command as `zig build test -j4 --summary all 2>&1 | cat` inside the remote build job. The remote wrapper may then redirect the pipe consumer's output safely. Keep WPT and other measurements outside build jobs, as before. Quote summaries and failure lines actually retained in the log, never reconstruct missing output from an exit status.

**Takeaway**: **The pipe requirement protects native build evidence as well as WPT logs: a successful exit cannot recover an overwritten summary.**
