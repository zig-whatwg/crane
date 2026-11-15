# Workflow: A watcher that reads a notice's LAST field misses a notice with one more field - parse by position and test the parser on the newest notice each time you arm it

**Date**: 2026-11-15
**Lesson**: A lane's closing-notice watcher took the host from the last field inside the notice's parentheses. The integrator's notices gained a fourth field (`owner <mirror>`), the pattern matched nothing, and the watcher went on watching without a word: it would have stopped no job.

**Why**: A watcher is the only thing that stops a lane's job while the lane waits inside a long command, and its failure is silent by construction: "no notice for my hosts" and "a notice I could not read" print the same nothing. A pattern anchored on the END of a line of prose written by another agent breaks the first time that agent adds a detail. The notice's format is not a contract; its first fields are the stable part.

**What Happened**: Lane wrap1's `watch.sh` read the host with `s/.*CLOSING NOTICE ([^)]*, \([a-z0-9.]*\)).*/\1/p`, which needs the host to be the last field. The notices of 12:49 PM ET and 2:26 PM ET read `CLOSING NOTICE (integrator, 2:26 PM ET, server1, owner dm2-l): ...`. The watcher was armed through both and wrote no STOP file. No job ran inside a closed window only because the pool itself holds a new job while a host is closed (the gate job posted one minute after the notice sat queued on the Mac); a job already running on that host would have run on. It was found by reading held-files.md after an unrelated wait, not by the watcher.

**Fix**:
1. Take the host by position: the text inside the parentheses, split on `, `, third field (`who, time, host[, more]`).
2. When you arm the watcher, run its parser over the newest `CLOSING NOTICE` line of held-files.md and print the host it finds. No host from a real notice is a broken parser: do not start a pool job.
3. Make "a notice I could not parse" loud: a notice line that yields no host writes a STOP-review file and ends the watcher, as an exception it cannot read does.
4. Edit the script by writing a new file and moving it over the old one, with the running watcher stopped first (a running bash script is read as it runs).

**Takeaway**: **A watcher that finds nothing must be able to tell "nothing for me" from "nothing I could read". Parse another agent's line by its first fields, and prove the parser on the latest real line every time you arm it.**
