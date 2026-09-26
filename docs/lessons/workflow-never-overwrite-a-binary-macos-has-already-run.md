# Workflow: Never overwrite a binary macOS has already run; remove it first

**Date**: 2026-09-25
**Lesson**: `cp zig-out/bin/wpt_runner tmp/bin/x` over an existing `tmp/bin/x` that has been executed makes the next launch die with exit 137 (SIGKILL) and no output at all.

**Why**: the kernel caches a binary's code signature per inode. Overwriting the file in place leaves new bytes under the old cached signature, so the loader kills the process.

**Fix**: `rm -f tmp/bin/x && cp zig-out/bin/wpt_runner tmp/bin/x`. A sweep or A/B that "produced no journal" with exit 137 is this.

**Takeaway**: **Exit 137 before the first line of output is code signing, not the engine.**
