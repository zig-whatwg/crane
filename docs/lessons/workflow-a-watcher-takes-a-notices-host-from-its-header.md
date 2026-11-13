# Workflow: A watcher takes a closing notice's host from its header, not from anywhere in the line

**Date**: 2026-11-11
**Lesson**: A CLOSING NOTICE watcher must read the closed host from the notice's header, `(<owner>, HH:MM UTC, <host>)`, and compare it exactly; matching the host's name anywhere in the notice and its EXCEPTION lines stops jobs on hosts that are not closing.

**Why**: Notices and their addenda name other hosts in their text (where a lane's other work runs, which host an exempt job is on).

**What Happened**: Lane fw1 b2's watcher grepped the notice block for "server1"; the 15:14 UTC notice closed chat.local, and an addendum mentioned server1, so the watcher wrote the server1 stop file for a run that was free to go (caught before the next run started; the file was removed and the watcher re-armed with `sed -n 's/^CLOSING NOTICE[^(]*([^,]*, [0-9:]* UTC, \([^)]*\)).*/\1/p' | grep -qx "$host"`).

**Fix**: Parse the header's host, compare with `grep -qx`, and test the parser on a real notice and addendum line before arming it.

**Takeaway**: **Match a notice's host where the notice states it, exactly - never by a substring of its text.**
