# Testing: A spin-count red test needs a timer shorter than the host's sleep slice

**Date**: 2026-11-16
**Lesson**: A test that counts an event loop's turns to show "it spins through a timer's last sub-millisecond" is red only where the sleeps before that sub-millisecond end short of the deadline. Arm timers that are under one slice away from the moment they are armed, so the whole delay is the part under test on every host.

**Why**: The loop waited for a timer in 1 ms slices while the timer was a whole millisecond or more away, and then turned without a wait. How long a 1 ms sleep really takes is the host's: 1.25 to 2 ms on a Mac (lane flk2's measurement, docs/lessons/testing-a-lateness-bound-in-milliseconds-measures-the-hosts-scheduler.md), close to 1 ms on server1 (Linux). With a 3 ms timer, two macOS sleeps can already reach the deadline, and the spin never starts; on Linux the slices end short of it and the loop spins for the rest.

**What Happened**: Lane ev2's red test for the V8 adapter's standalone loop chained forty 3 ms timers and bounded the timer polls at 800. On main it made 176,325 polls on server1 and passed on chat2.local - a red test on one host and a green one on the other, for the same unfixed code. With forty 1 ms timers (under a slice away when armed, so the old code's whole-millisecond count read 0 at once) main's timer files made 206,922 polls on server1 and 160,712 on chat2.local - the control fails on both hosts - and with the fix both pass.

**Fix**:
1. Choose the timer so that the unfixed code's wrong branch is taken at the moment the timer is armed, not after some number of sleeps: here a delay of one slice.
2. Keep the assertion a count with a wide margin (ten turns a timer allowed, two expected), never a duration.
3. In the tests that must NOT fire a timer, arm it ten seconds away: a thread that runs late cannot make it due.
4. Run the red on every OS the gate runs on before writing the fix (docs/lessons/testing-a-red-test-must-run-where-the-failure-runs.md), and keep a control step that swaps the old files back in a pool mirror.

**Takeaway**: **A test of "the last fraction of a slice" must make the whole delay that fraction: a multi-slice timer leaves it to the host's sleep length whether the bug's branch is ever reached.**
