# Workflow: A Linux gate names its OS, or the pool moves the mirror to a Mac

**Date**: 2026-11-14
**Lesson**: `crane-remote.sh <mirror> <cmd>` with no `--os` places the job on a macOS host - and a mirror whose home is server1 is MOVED there (crane-pool syncs its tmp/ over and resets its home), so a "server1 freeze" quietly builds macOS runners that no Linux A/B can use.

**Why**: The pool's default OS is macOS (crane-remote.sh: "With no --os a job goes to a macOS host"); a mirror's home only steers non-build jobs, and a build job takes any eligible host of the job's OS. Earlier rep1 gates reached server1 because they were launched with `--os linux`; a re-armed launcher written later from memory dropped the flag.

**What Happened**: Lane rep1 b2 armed its pre-A/B gate to start at server1's GAP OPEN (`on-gap.sh server1 ... crane-remote.sh rep1-l "bash .rep1/gate-pre.sh ..."`). It started at 15:38, was placed on chat.local, moved rep1-l there, and ran 12 minutes of macOS root compiles inside a host the integrator had opened for other work, until the integrator saw rep1-l on chat.local in `crane-pool.sh status`. Stopped by its exact pid tree; the chat.local copies deleted; rep1-l's pool home set back to server1; the freeze waited a whole window.

**Fix**: Pass `--os linux` to every server1 job, and make the command refuse a wrong host itself: `[ "$(uname)" = Linux ] || { echo 'GATE FAILED: not on Linux'; exit 9; }; bash .rep1/gate-pre.sh ...`. After a job starts, read its `placed on <host>` line before walking away.

**Takeaway**: **A job meant for one OS says so twice - `--os` to the pool and a `uname` check in the command - and its "placed on" line is read the moment it starts.**
