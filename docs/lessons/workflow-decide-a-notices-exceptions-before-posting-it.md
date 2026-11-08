# Decide a notice's exceptions before posting it, and write them in the same append

**Context:** 2026-11-08 21:35 UTC. The integrator posted a CLOSING NOTICE for server1 (flaky5's window), then looked at what ran there, saw perf2's nearly finished PRE gate, and posted an EXCEPTION line for it about a minute later, in a second write. perf2's watcher (which waits 20 s after a notice, then reads the EXCEPTION lines that follow it) had already read the notice without the exception and killed the gate. The gate's tests had to be rerun elsewhere.

**Lesson:** A watcher can only honour what is in the file when it reads. The integrator must list the host's running jobs FIRST (`ps` on the host), decide which ones are exempt, and append the CLOSING NOTICE and its EXCEPTION lines in ONE write. An exemption decided after the notice is a kill, not an exemption.

**How to apply:** before every CLOSING NOTICE: (1) list the host's lane jobs, (2) decide exemptions, (3) write the notice and every EXCEPTION line in the same heredoc. If a job is noticed only afterwards, do not post a late EXCEPTION - let it stop and say so to its lane. Related: workflow-a-notices-exception-can-follow-it-on-lines-of-its-own.md, workflow-a-notice-that-says-no-exception-reads-as-an-exception.md.
