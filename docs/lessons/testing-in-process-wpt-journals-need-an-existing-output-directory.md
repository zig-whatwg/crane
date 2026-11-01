# Testing: In-process WPT journals need an existing output directory

**Date**: 2026-11-01
**Lesson**: Create a fresh output directory before an in-process WPT invocation that writes its journal there.

**Why**: The supervisor creates its output directory before opening a journal. The in-process path calls `Journal.create` directly; creating the file does not create its parent directory.

**What Happened**: A lifetime check discovered its page, printed the run header, then exited with `FileNotFound` before writing any test result. Its scratch launcher supplied a new `--output` and nested `--journal` path without creating the directory. Earlier supervised runs had concealed the omission. The collector subsequently failed on the missing result directory.

**Fix**: Preserve the failed attempt, create the fresh owned directory without allowing an overwrite, and keep setup inside the authentication bracket. Use a separately recorded successor for the corrected invocation. Keep leak measurements in-process: adding supervision would make `leaks --atExit` inspect the wrong process.

**Takeaway**: **Directory setup is part of the measurement; a discovered test and a run header are not evidence that its assertions executed.**
