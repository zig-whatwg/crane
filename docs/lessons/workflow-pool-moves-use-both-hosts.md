# Workflow: Pool Moves Use Both Hosts

**Date**: 2026-10-29
**Lesson**: Check timed-window restrictions on a mirror’s current home before submitting a job that may move it.

**Why**: Pool placement can select an open destination while its transfer runs rsync on a closed source host. The destination’s available slot or runner token does not account for that source-side activity.

**What Happened**: Row 130 was authorized to copy a named main freeze on chat.local while row 127 measured costs on closed chat2.local. Row 130’s mirror still lived on chat2, so the generation-pair command first moved its mirror and frozen binaries to chat.local. That transfer ran rsync on chat2 during the protected window, even though the submitted command used no build slot or runner token there. The liaison disclosed the overlap to the measurement owner; its existing load and VOID rules governed the result. A subsequent corrected artifact copy stayed on chat.local and required no transfer.

**Fix**: Immediately before submitting a pool job, read the mirror’s current home and the host-scoped coordination notices. If its home is closed, wait for that host’s explicit GAP OPEN even when the intended destination is open. Once both ends permit the move, use the ordinary pool operation and record the transfer. Let the measurement owner handle any already-observed overlap; do not change its evidence or pool state. The integrator subsequently made pool_follow refuse moves off a host closed for another mirror’s timed window. Treat that exit as a wait until GAP OPEN; never force the placement.

**Takeaway**: **A timed-window check must cover both ends of a mirror transfer.**
