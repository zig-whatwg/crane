# Workflow: An ssh inside a `while read` loop eats the rest of the list

**Date**: 2026-11-05
**Lesson**: A STOP watcher that walks its list of remote pids with `while read -r m p; do crane-pool.sh on "$m" "kill ... $p"; done < remote-pids` stops only the FIRST job: the ssh under `crane-pool.sh on` reads its stdin, which is the loop's, and takes every remaining line with it.

**Why**: Inside `while read ... done < file`, every command in the body inherits the file as its stdin. `read` consumes one line; ssh then forwards whatever stdin still holds to the remote command, so the next `read` finds end of file and the loop ends after one iteration. Nothing fails and nothing prints: the remote command ignores the input, and the loop's exit status is 0.

**What Happened**: Lane perf0b's watcher fired on a 23:47 UTC CLOSING NOTICE for chat.local. Its list held two pids: a build job that had already ended, then the gate (pid 36627). The first `crane-pool.sh on` swallowed the gate's line, so the gate was never signalled. Its STOP files were still touched, in a separate loop over the mirror names. Reading the gate still alive, with its `zig build test` running, the lane first concluded that "a crane-remote job ignores SIGTERM". It was disproved minutes later: the same SIGTERM, sent to the gate's whole tree by exact pids, ended it at once. The notice had in fact exempted the lane's running jobs, so the bug happened to cost nothing that time. On a notice without an exemption, the gate would have kept its build slot through another lane's window.

**Fix**: Every remote call inside such a loop reads `/dev/null` (`crane-pool.sh on "$m" "..." < /dev/null`; `ssh -n` does the same for a bare ssh). After any stop, list the job's tree on its host (`ps -ax -o pid,ppid,command`) before saying it is gone. The fixed watcher is tmp/plans/perf0-scripts/watch.sh.

**Takeaway**: **In a `while read` loop, every command that can read stdin will read the loop's list: give each remote call `< /dev/null`, and check after a stop that the tree is really gone, instead of explaining why it survived.**
