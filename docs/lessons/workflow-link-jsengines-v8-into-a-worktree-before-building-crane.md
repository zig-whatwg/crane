# Workflow: Link jsengines/v8 into a worktree before building crane

**Date**: 2026-10-23
**Lesson**: In a worktree with no `jsengines/v8`, `zig build crane` (and `browser`) quietly starts a full V8 fetch from source: depot_tools, `fetch v8`, `gclient sync`. It wrote 4.4 GB in 20 minutes before it was stopped.

**Why**: The `crane` and `browser` steps depend on two shell steps in build.zig, `fetch_v8` and `build_v8`, which bootstrap V8 when its static library is missing. A git worktree has no `jsengines/` (it is untracked), so the library is missing there and the bootstrap runs. Other V8 steps (`wpt-runner`, `test-browser`) do not depend on these steps: they fail at once with "libv8_monolith.a: file not found". A failure like that is easy to diagnose; a background download is not. Until 2026-10-23, `fetch_v8` also cloned depot_tools (772 MB) even when the prebuilt was present. That happened in every chat mirror, whose `jsengines/v8` is a link and which has no depot_tools. Since 6846c75fd8e, the steps run only when the library is missing.

**What Happened**: Lane linuxbuild1 ran `zig build crane` in its worktree to test a webdriver fix. The build log showed `gclient` working on `v8/third_party/icu` and the LLVM toolchain download 26 minutes in. On chat, the same step had put 772 MB of depot_tools into the lane's mirror.

**Fix**: Before any V8 build in a worktree, link the prebuilt the main checkout holds: `mkdir -p jsengines && ln -s /Users/bcardarella/projects/crane/jsengines/v8 jsengines/v8` (crane-remote.sh does the same on chat). If a fetch has started, kill its processes by pid, then delete `jsengines/` and the vpython store entries it created (`~/Library/Caches/vpython-root.<uid>/store`, by mtime).

**Takeaway**: **A worktree has no jsengines/: link the V8 prebuilt before building anything that links V8, or `crane` fetches V8 from source.**
