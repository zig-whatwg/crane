# Workflow: A job chained with && runs only as far as its first failure - report what its log shows, not what its command says

**Date**: 2026-11-13
**Lesson**: A pool job written as `check && measure && measure; next` skips every measurement when the check fails, and still looks like a job that is running; say what a job is doing only from what its log shows it started.

**Why**: `&&` makes each step a precondition of the next. That is right when the next step consumes the previous one's result, and wrong when the first step is an independent check: its failure - for a reason that has nothing to do with the builds behind it - cancels them without a word. The job keeps its slot, runs whatever follows the `;`, and ends with a status that describes only its last command. Nothing prints "skipped".

**What Happened**: Lane build2's first server1 job was `config.sh base twice && proof.sh cold control1 && proof.sh cold control2 && proof.sh compare control1 control2; ...; proof.sh build base && proof.sh compare control2 base`: capture the configuration twice, then the two cold control builds the design asks for, then the warm build. The configure check returned 1 - two configures of one tree differed in three padding bytes per declared option, a finding of its own ([the printed configuration is the steps, not the graph](workflow-zig-017s-printed-configuration-is-the-steps-not-the-graph.md)) - so both cold builds were skipped, and the `build base` after the `;` ran for 28 minutes, which from outside looked exactly like the control builds running. Seven minutes after starting the job the lane told the integrator that server1 "is running two cold control builds". It learned otherwise 29 minutes later, when the job ended and its last line said `compare: missing tmp/build2/hashes/control2.sha256`. The same command on chat.local did run them (the check passed there), so the two hosts' jobs had diverged silently. Cost: the second cold build started half an hour late, and one status message had to be corrected.

**Fix**:
1. Join steps with `&&` only where the next step consumes the previous one's output. An independent check is followed by `;` with its status printed (`bash config.sh base twice; echo "config rc $?"`), so the log says what happened and the job goes on.
2. Each step prints a line when it STARTS (`[control1] wiping ...`), so `crane-pool.sh on <mirror> 'tail tmp/crane-remote-*.log'` shows which step a running job is in.
3. Before telling anyone what a long job is doing, read that line. "I started a job whose command includes X" is not "X is running".
4. When a status you sent turns out to be wrong, the correction is the first line of your next message, with what ran instead.

**Takeaway**: **`&&` after a check makes the check a gate on everything behind it: use it only for real dependencies, print each step's start and status, and report a job's progress from its log, never from its command line.**
