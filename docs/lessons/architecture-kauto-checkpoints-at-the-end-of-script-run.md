# Architecture: Under kAuto, V8 checkpoints at the end of Script::Run - before the host can report

**Date**: 2026-09-26
**Lesson**: HTML "run a classic script" reports an exception (8.3.1) and only then "cleans up after running script" (8.3.2), whose microtask checkpoint runs the script's promise reactions. Under V8's kAuto policy the checkpoint happens inside Script::Run's exit when the call depth returns to zero - so reactions ran before the ErrorEvent.

**Fix**: protocol_scripts runs the evaluation and the report under Isolate::SuppressMicrotaskExecutionScope (v8_RunWithMicrotasksSuppressed), which also holds the call depth above zero, and performs the checkpoint itself in cleanUpAfterRunningScript - Blink gets the same order from the MicrotasksScope around its script run. Pinned by "what a classic script throws is reported before the microtask checkpoint".

**Takeaway**: **With kAuto the checkpoint belongs to V8's call depth; hold the depth up until your own "clean up after running script".**
