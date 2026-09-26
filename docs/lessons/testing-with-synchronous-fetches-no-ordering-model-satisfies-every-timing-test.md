# Testing: With synchronous fetches, no ordering model satisfies every timing test

**Date**: 2026-09-26
**Lesson**: execution-timing/085 wants an async script to run before deferred ones; 088 and 112 want a slow async script to run after them.

**Why**: Both are right only with real network timing; with synchronous fetches every async script is "fast".

**What Happened**: Any single ordering passes one group and fails the other.

**Fix**: Pick the common case (async before defer at the end of parsing) and state the deviation until fetches are asynchronous (lane/scripting 7e18ea8e4).

**Takeaway**: **When timing tests contradict each other under a synchronous engine, choose the common case and write the deviation down.**
