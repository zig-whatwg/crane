# Workflow: An EXCEPTION can exempt the jobs a notice lists without naming them

**Date**: 2026-11-11
**Lesson**: A closing notice lists the jobs on its host and its EXCEPTION may refer back to them ("both run to their end"). A watcher that looks for its lane's name or pid only in the EXCEPTION text kills an exempt job: when the notice names the lane and carries any EXCEPTION, the watcher must kill nothing and hand the decision to the agent.

**Why**: The watchers grep the text after "EXCEPTION:" for their lane name or a pid they recorded (lessons on 2026-11-05 and 2026-11-06 added that path). The integrator writes notices for people, and a person reads "Jobs listed first: ... nd2 b3's tip console build ... and style1's test run. EXCEPTION: both run to their end" as an exemption for nd2. The script did not.

**What Happened**: 2026-11-11 01:09 UTC, chat.local closed for lane cg1's window. The notice listed nd2's running release-console build (mirror nd2-cl) and exempted "both" listed jobs. nd2's watcher found neither "nd2" nor its pid after "EXCEPTION:", sent TERM to the build's tree and wrote a STOP file in the mirror's bins. The build, about 15 minutes of a ReleaseSafe root, was lost and had to be queued again on the other macOS host. The lane removed the STOP file, posted the kill, and changed the watcher.

**Fix**: In the watcher, after reading the notice and every EXCEPTION line:
1. If the notice names the lane (anywhere in its text) and any EXCEPTION is present, kill nothing and write no host STOP. Write STOP-review and exit, so the agent reads the notice and decides within minutes.
2. Kill without asking only when no EXCEPTION is present, or when the text says "No EXCEPTION".
3. After any kill, confirm on the host that the tree is gone and remove your own STOP-<host> file before the next job there.

**Takeaway**: **An exemption can point at a job by the notice's list, not by name: when a notice names your lane and carries an EXCEPTION, ask, do not kill.**
