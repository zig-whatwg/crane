# Debugging: A diagnostic table that can drop events must count them and reconcile with an independent total

**Date**: 2026-11-17
**Lesson**: A fixed-size histogram added for a diagnosis must count what it could not record and print its own total, and its reader must refuse to print the table unless that total equals a count taken another way.

**Why**: A diagnosis patch is written quickly and read once. A table that silently stops recording when it is full still prints rows, sorted, with plausible numbers. Nothing in its output says how much of the run it saw.

**What Happened**: Lane vm1 wanted to know which adapter functions make the Globals of one `new ReadableStream(...).getReader()` (52 an operation, by the adapter's creation counter). The first patch keyed a 16,384-entry open-addressing table by `__builtin_return_address(0)` inside the handle-tracking function and returned without recording when the table was full. The dump of a run that made 10,400,003 Globals held 16,384 entries whose counts summed to 30,691 - 0.3% of the creations - and 9,131 of the entries had a count of 1, so the key was not a stable call site either (why was not found). The row script still printed a header and "total 0.15 per operation over 16384 sites" for five different statements, the same 0.15 for each, including one statement that makes no Global at all. No row was printed under those headers only because none passed the script's 5% threshold: nothing in the script knew the table was wrong. Two dump files of different statements had the same byte size (229,450), and the one whose lines were counted had 16,385 - a full table of 16,384 and one header line - which is what gave it away.

**Fix**:
1. Key by something stable and small. For "which C++ function made it", define a macro after the tracked function so every later call site passes `__func__` - one static string a function - and key the table by that pointer (`.vm1/var-sites2.patch` in lane vm1's scripts).
2. Count every event (`total`) and every event the table could not place (`dropped`), and write both into the dump.
3. In the reader, print the table only when `dropped == 0`, the rows sum to `total`, and `total` equals the run's independent counter (here `globals_created` at the run's last reading). Otherwise print "NOT RECONCILED" and the numbers that disagree.
4. Treat a result from the unreconciled form as void: keep it out of every report, and say in the handoff which numbers came from where.

**Takeaway**: **A table that cannot say how many events it missed has measured nothing. Reconcile every diagnostic count with an independent total before you read a single row of it.**
