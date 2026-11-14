# Workflow: A WPT update's cutover moves every tree in one window, and the main checkout's submodule moves last-but-one

**Date**: 2026-11-14
**Lesson**: A WPT update changes the base of every lane's comparison. Prepare everything outside the hosts first, then move the fork, the main checkout, the hosts' live trees and the serves in ONE closed window, in a fixed order. Bump the main checkout's submodule only inside that window.

**Why**: Each pool host has one live tree (`~/crane-work/main/tests/wpt`) and one `wpt serve`. The runner reads files from `--wpt-root` but fetches them over HTTP from the serve, so a comparison across two WPT revisions is meaningless. A `crane-remote.sh` job named `main`, run from the main checkout, rsyncs that checkout's `tests/wpt` with `--delete` into its host's live tree. So bumping the submodule early moves a host under whichever lane runs there next. Before this update every frozen generation also linked the live tree, so an old generation would have run the new tests without a word.

**What Happened**: The first update after the pin (lane wptup1; upstream afe89a5df4 -> 2358bd4835) took its cutover in a 1 h 40 min window (07:02-08:42 UTC, 2026-11-14), after lanes quick1 and rep1 had finished their A/Bs on the old tree:
- the old tree was copied to `~/crane-wpt/<rev10>`, and all frozen dirs were relinked to that copy;
- the sync branch was pushed, then the main checkout's submodule was fast-forwarded (wrap1's uncommitted Crane tests survived it);
- `sync-wpt` and the serve restarts followed;
- then the gate, the runner compatibility check, and the WPT-update generation (224), whose 34 losses were each explained by an upstream test change;
- the fork's main moved last.
The procedure is docs/wpt-update.md.

**Fix**: Follow docs/wpt-update.md. In short:
- Outside the window: the sync commit, the manifest, the worklist, the harness diff, and the snapshot of the old tree.
- In the window, in this order: scripts, then frozen links, then the branch push, then the main checkout's submodule, then merge, then live trees, then serves, then gate, then compatibility, then the update generation, then the fork's main.
- Each step has a check and an undo.

**Takeaway**: **The submodule bump is a host operation in disguise: it moves trees through crane-remote's rsync. Keep it inside the window, after the frozen generations have their own copies.**
