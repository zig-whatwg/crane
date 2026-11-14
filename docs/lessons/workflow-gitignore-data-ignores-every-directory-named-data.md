# Workflow: .gitignore's `data/` ignores every directory named data

**Date**: 2026-11-12
**Lesson**: The root .gitignore's `data/` line (for the datasets `zig build setup` downloads) has no leading slash, so it ignores a directory named `data` anywhere in the tree - a new fixture directory called data is silently untracked.

**Why**: A gitignore pattern without a leading or middle slash matches at any depth. `git status` then lists nothing for the new files, so nothing looks wrong until the commit lacks them and a pool host or a reviewer finds the workload's files missing.

**What Happened**: Lane quick1 b3 added the precompressed perf bodies as tests/perf/data/text-1m.html.{gz,br}. `git status --short` showed only the edited suite and server; `git check-ignore -v` named `.gitignore:56:data/`. The directory became tests/perf/encoded/.

**Fix**: Before naming a new directory of committed files, run `git check-ignore -v <path>`; after adding files, check `git status --short` lists them. Avoid `data/`, `deps/` and the other root ignores' names for anything meant to be committed.

**Takeaway**: **A new file `git status` does not list is ignored, not absent: `git check-ignore -v` says by which line.**
