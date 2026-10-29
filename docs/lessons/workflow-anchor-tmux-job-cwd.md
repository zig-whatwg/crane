# Workflow: Anchor a Tmux Job to Its Own Working Directory

**Date**: 2026-10-29
**Lesson**: A detached job must establish and verify its working directory inside the shell that runs it.

**Why**: An absolute script path identifies the script, but its relative file reads and output paths still depend on the child shell's working directory. Starting a tmux session does not prove that shell reached the intended workspace.

**What Happened**: Row130's first dialog-prefix gate launcher created a detached session, then exited before creating its result directory or starting any gate. Its pool log showed only the successful script upload. A light probe using the same launch shape reported `PWD=.` and could not find the lane's source-seal file. Adding tmux's `-c` option alone produced the same probe result on that host. An explicit absolute `cd` inside Bash returned the lane's physical path and found the source seal. These observations establish the failure and remedy; they do not establish why that tmux child started in that state.

**Fix**: Pass the script's absolute path. Inside the script, resolve its own directory from `${BASH_SOURCE[0]}`, derive and validate the lane root, and change to that root before accessing relative paths. Capture startup output at an absolute path outside the gate's result directory so an early failure remains visible. Keep the pool job alive until its tmux session ends, and verify the source seal, gate timestamps and exit receipts before claiming a build or test result. Preserve the failed attempt separately; a launcher failure is not a failed product test.

**Takeaway**: **Verify the working directory inside the detached job, and retain evidence from before its first gate starts.**
