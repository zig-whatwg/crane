# Workflow: Detached Inputs Need a Verified Transfer

**Date**: 2026-10-29
**Lesson**: Transfer scratch inputs explicitly and make their verification a condition of starting a detached job.

**Why**: A source sync can intentionally exclude scratch files. A shell using `set -uo pipefail` also continues after a failed standalone command unless its status is checked.

**What Happened**: A native regression launcher assumed the pool source sync included its new scratch script. Its hash checker failed with FileNotFoundError, but the shell continued and created a tmux session whose script did not exist. No tests ran. A proposed explicit-upload command then exceeded a safe argument size because it embedded a large source manifest; that size problem was caught locally before submission.

**Fix**: Explicitly upload the sealed inputs into the lane's scratch directory, refuse different existing bytes, and verify every on-disk hash. Add an explicit failure exit to the upload/check command before creating tmux. Compress the transport payload when needed, verify that decoding reproduces the exact sealed bytes, and check the final command size before submission. Preserve failed launcher evidence and prove its processes ended before trying the corrected launcher. A launcher failure is never behavioral RED evidence.

**Takeaway**: **Source sync, verified scratch transfer, and detached execution are separate steps; each must succeed before the next starts.**
