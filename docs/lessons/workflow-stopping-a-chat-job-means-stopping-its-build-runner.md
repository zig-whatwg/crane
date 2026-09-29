# Workflow: Stopping a chat job means stopping its build runner

**Date**: 2026-09-28
**Lesson**: Killing `crane-remote.sh` here, or the job's script on chat, leaves `zig build`'s build runner and its compile/test children running on chat. They keep a slot's worth of CPU and memory until they are killed by process id.

**Why**: `crane-remote.sh` runs the command over `ssh ... bash -s`, and the remote side does not die with the local client. Killing the remote script (`pkill -f networking-gate3.sh`) ends only the shell. `zig build` runs a separate build-runner executable (`~/crane-cache/o/<hash>/build`), which launchd adopts once its parent `zig build` is gone, and that runner keeps starting `zig test` children for steps still queued.

**What Happened**: A c22 gate had to be stopped twice: once to rework the change, and once to merge main before gating. Both times `pkill` of the local client and the remote script looked complete, because `pgrep -f networking-gate3` came back empty. But `zig build test` (pid 510), its build runner (pid 513, parent 1) and the runner's `zig test` compiles were still going. Killing 510 did not stop them, because the runner was already orphaned. Each kill of a `zig test` child was followed by the runner starting the next.

**Fix**:
1. Kill the local `crane-remote.sh` and the remote script as before.
2. On chat, list every process whose working directory is the lane's mirror, whatever its command line:
   ```bash
   for p in $(pgrep -f "zig|/test|wpt_runner"); do
     c=$(lsof -a -p $p -d cwd -Fn 2>/dev/null | grep ^n | cut -c2-)
     [ "$c" = "$HOME/crane-work/<mirror>" ] && echo "$p $(ps -o ppid=,command= -p $p | cut -c1-80)"
   done
   ```
3. Kill the build runner (the `~/crane-cache/o/.../build` process, parent 1) first, then what is left, and run the listing again until it is empty.
4. Check `~/crane-slots/`: the job's slot directory goes when its `bash -s` does.

**Takeaway**: **A chat job is stopped when nothing is left running in its mirror's directory, not when its script is gone. The orphaned build runner is the one that keeps going.**
