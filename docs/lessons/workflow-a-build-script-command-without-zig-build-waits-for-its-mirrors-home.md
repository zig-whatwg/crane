# Workflow: A crane-remote command that builds through a script waits for its mirror's home

**Date**: 2026-11-10
**Lesson**: crane-remote.sh decides whether a job is a build by the command's TEXT: a command with no `zig build` in it is not a build and runs on the mirror's home only. A wrapper script that builds (`bash .lane/build-mac.sh <label>`) is therefore pinned to the host of the mirror's previous job, and queues there while other hosts sit idle.

**Why**: tmp/remote/pool-lib.sh pool_place_build: "not a build (no `zig build` in the command) and the mirror has a home: the home only". The rule keeps reads and light commands beside the mirror's files; it cannot see inside a script.

**What Happened**: Lane style1 batch 1 queued `crane-remote.sh style1 'bash .style1/build-mac.sh tip-c00d2bb571d'` while its mirror's home, chat2.local, had both build slots busy. For nine minutes it printed "no room for style1 yet - chat.local: 0/5 slots busy ... queued": chat.local was open and empty, but the job's only eligible host was chat2. The Mac-side queue (tmp/remote/pool/build-q) showed the ticket listing chat2.local alone. Relaunched as `'true zig build; bash .style1/build-mac.sh ...'`, the same job was eligible everywhere (and waited the normal cold-build minutes for its warm home before taking chat.local).

**Fix**: When a crane-remote command builds through a script, put `zig build` in the command text (`true zig build; bash <script>`), or call `zig build` in the command itself. To see why a queued job waits, read its ticket in tmp/remote/pool/build-q/: it lists the hosts the job may take.

**Takeaway**: **crane-remote sees a build only by `zig build` in the command text: a build script without it is pinned to its mirror's home.**
