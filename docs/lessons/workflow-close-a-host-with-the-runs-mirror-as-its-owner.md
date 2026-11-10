# Close a host with the run's MIRROR as its owner, not the lane's name

**Context:** 2026-11-10, 11:57 UTC. The integrator closed server1 for lane nd1's FULL A/B with `crane-pool.sh close server1 nd1 ...`. nd1's run used its Linux mirror, `crane-pool.sh wpt nd1-l --pair generation ...`. At WINDOW GO (12:14) the run did not start: crane-pool said "no open host for nd1-l's run yet ... waiting for its window to end". A closed host admits only runs whose mirror is the closure's owner, and `nd1` is not `nd1-l`. The A/B waited until the host was re-closed with owner `nd1-l`. The same happens to every lane whose Linux mirror carries the `-l` suffix.

**Lesson:** a window's owner is a MIRROR name, the one the window's runs pass to crane-pool.sh. The lane's name is only the same on its macOS mirror.

**How to apply:** before `crane-pool.sh close <host> <owner> ...`, read the exact launch command the lane sent (READY FOR A/B / READY for a window) and use its mirror argument as the owner: `nd1-l` on server1, `nd1` on chat.local. When one closure serves two lanes in turn, re-close with the next lane's mirror at its WINDOW GO. Related: workflow-an-end-line-is-the-cue-to-post-gap-open.md.
