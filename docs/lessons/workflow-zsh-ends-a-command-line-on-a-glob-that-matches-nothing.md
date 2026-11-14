# Workflow: zsh ends a command line on a glob that matches nothing

**Date**: 2026-11-12
**Lesson**: In zsh an unmatched glob is an error that ends the whole command line (`no matches found`), so `rm -f dir/STOP-* && start-something` starts nothing. Delete optional files by exact name, or run the line under `bash -c`.

**Why**: The agent's Bash tool runs each command through zsh. bash passes an unmatched pattern through as a literal and `rm -f` ignores it; zsh's default (NOMATCH) aborts before `rm` runs, and everything chained after it with `&&` never runs. `-f` does not help: the failure is the shell's, not rm's.

**What Happened**: Lane v8up b6c armed its closing-notice watcher with `rm -f tmp/scratch/v8up/watch.done tmp/scratch/v8up/STOP-* && FIRE_EXIT=1 bash watch.sh > watch.log`, as a background command. No STOP file existed. The background task "failed with exit code 1" within a second; its output held `(eval):1: no matches found: tmp/scratch/v8up/STOP-*`, the log file had never been created, and `watch.done` was still there. Had the notification been read as "the watcher fired", the lane would have run pool jobs with no watcher. The same shape had appeared ten minutes earlier with `grep --include=*.zig` (unquoted) and looked like an empty search result.

**Fix**: Name the files (`rm -f a/watch.done a/STOP-chat.local a/STOP-server1`), or quote the pattern for the program that expands it itself (`grep --include='*.zig'`, `find -name 'STOP-*' -delete`), or wrap the line in `bash -c '...'`. After starting any watcher in the background, read its first log line ("armed at line N") before the first pool job.

**Takeaway**: **A background command that exits at once with status 1 and an empty log did not start: read its output for `no matches found` before assuming it ran. Never put an optional glob in front of `&&`.**
