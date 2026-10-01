# Workflow: An ignored unknown flag runs the whole corpus

**Date**: 2026-10-01
**Lesson**: `wpt_runner` skipped any `-`-prefixed argument it did not know. A flag the binary predated therefore ran the default, which is every in-scope file, serially and outside the runner-token pool.

**What Happened**: a remote job chained `zig build wpt-runner ...; ./zig-out/bin/wpt_runner --allocator-self-check`. The build failed (a link error), so the binary left in zig-out was the old one, which had no such flag. It started 9,278 runs on chat and was killed 7 minutes later.

**Fix**: `parseArgsDiagnosed` returns `error.UnknownOption` and names the argument, and the runner exits 2 with `wpt_runner: unknown option <arg>`. `--verbose`, which `zig build wpt -Dwpt-verbose` passed and the parser had never known, is an option now. Chain a binary after its build with `&&`, or test the build's exit code first.

**Takeaway**: **An option a program does not know must be an error. If it is ignored, the run does something other than what was asked, and here the default was the most expensive thing the program can do.**
