# Workflow: Timed windows go through the window queue, which hands a quiet host on and checks the window moves

**Date**: 2026-11-20
**Lesson**: Enqueue a timed window with `crane-pool.sh queue` instead of hand-scheduling it: the host's keeper drains the host, starts the window with its mirror named, hands the host on, and checks every 10 minutes that a started window is actually moving.

**Why**: Hand-scheduled windows were serial, and every step waited for someone to read a message. The integrator closed a host, waited for its builds to drain, sent WINDOW GO, waited for the lane to launch, and opened the host again afterwards. Nothing checked that a started window was doing anything: the integrator watched for the END message, and the lane's waiter watched for its done marker. `crane-measure.sh` also read a sweep's mirror from its working directory. A window script that swept from the shared WPT tree (`~/crane-work/main/tests/wpt`) without `CRANE_POOL_MIRROR` therefore read as "main", and its FULL sweep waited for its own window to end.

**What Happened**: Lane maj1's combined FULL A/B started in its window on server1 at 8:18 PM ET on 2026-11-19. Its production sweep printed one line, "the host is closed for a timed window ...", and then waited without any further output. The integrator found it at 4:14 AM ET: server1 had been closed for about 8 hours with nothing running in it. The integrator then named hand-scheduled windows the biggest productivity bottleneck, and the user asked for the queue ("build the window queue", lane wq1).

**Fix**:
1. `tmp/remote/crane-wq.sh` is a keeper that runs on each pool host. It is detached, so a Wi-Fi handoff or a sleeping Mac cannot stall a handoff. For the next window in the queue it does four things:
   - It closes the host as owner `wq-drain` and waits for running build slots, runner-token holders, root runners, and a 1-minute load under the host's gate (`WQ_LOAD_MAX`; default 0.2 x cores: server1 6, chat.local 3).
   - It closes the host for the owner and runs the command exactly as `crane-pool.sh wpt` does, with `CRANE_POOL_MIRROR` exported.
   - Starting 10 minutes after the window starts, and every 10 minutes after that, it checks for CPU growth in the window's process tree or a changed file under the owner's `tmp/`, `wpt-results/` or `-bins/`. If neither is found it writes `ALERT <time> <host> <owner>: window not moving (<evidence>)`. A window running past twice its `--est` gets an ALERT too.
   - When the window ends, it opens the host or drains it for the next window.

   A close by hand always wins over the queue. Windows closed by hand get the same movement check.
2. A relay on the Mac copies the keepers' events (QUEUED, DRAIN, WINDOW START/END, HANDOFF, OPEN, ALERT) into `tmp/plans/held-files.md`. It is the LaunchAgent `com.crane.wq-relay`, every 60 s, plus an inline pass on every queue command and `status`.
3. `crane-measure.sh` finds a run's mirror from the first of these that applies:
   1. `CRANE_POOL_MIRROR`.
   2. The runner's path (`~/crane-work/<mirror>[-bins]/...`).
   3. For a frozen generation runner (`~/crane-frozen/main-*`): the window's owner, if the host is closed for an integrator mirror.
   4. The working directory.

   Its wait message names the mirror it found and the source. `crane-measure.sh mirror <runner>` prints both.
4. Lanes: `crane-pool.sh queue <host> <mirror> <ab|cost|sweep|short> --est <min> --note '...' '<cmd>'`, then ONE background `crane-pool.sh queue-wait <host> <mirror>`, which exits with the window's exit status (docs/agents/working-on-crane.md, "Timed windows: the window queue").

**Takeaway**: **Never hand-schedule a timed window or trust a window that has merely started: enqueue it, and let the keeper on the host hand the host on and check every 10 minutes that the window is moving.**
