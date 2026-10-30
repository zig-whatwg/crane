# Workflow: A queue wrapper's exit does not prove its build ended

**Date**: 2026-10-28
**Lesson**: Require the launched job's identity and complete phase receipts before declaring an interrupted queued build finished.

**Why**: A queue wrapper can launch a child between monitoring polls. If the wrapper then exits, previously observed children may all be gone while the new child keeps running. A slot registered to the wrapper can also disappear before its build ends.

**What Happened**: A turn interruption ended the local queue client and notice watcher. The remote queue process survived, waited for a slot, and launched the build. It then exited, leaving the new build adopted by PID 1 and no slot holder for the lane. A reattachment monitor had seen only the queue process and its sleep children; it falsely reported completion when those exited. Empty phase receipts exposed that the report contained no gate result. A direct identity check found the still-running build. The lane set its own STOP flag, cancelled only its captured build descendants, verified they were gone, and preserved the interrupted run as incomplete. The integrator subsequently reproduced the cause: writing the job PID to a vanished client's stderr raised SIGPIPE, triggering the wrapper's EXIT trap and releasing the slot. Its 2026-10-28 13:21 UTC relay records the shared helper fix and end-to-end checks; this lane did not modify that helper.

**Fix**: Preserve the failed monitoring evidence and correct its claim. Do not relaunch while any existing request or launched job survives. Record the actual job PID, the wrapper's real exit receipt, and each phase's command exit and Build Summary. For this lane's approved retry, the local client and notice watcher run in separate detached sessions with file-backed output, keeping their lifetime independent of a tool turn. The shared queue helper remains owned by the integrator.

**Takeaway**: **A process disappearing is not a completed gate; verify the launched work and its receipts.**
