# Workflow: pnpm keeps its store in the home directory unless told otherwise

**Date**: 2026-11-21
**Lesson**: A Node project installed with pnpm on a pool host writes its package store to `~/Library/pnpm` (macOS) and its state to `~/.local/state/pnpm`, outside the scratch directory, even when npm's and corepack's caches are pointed into it: set `npm_config_store_dir` (or `--store-dir`) into the scratch directory, or delete both paths when the probe ends.

**Why**: pnpm installs from a content-addressable store shared across projects; its default location is per user, not per project, and `npm_config_cache`, `COREPACK_HOME`, `PLAYWRIGHT_BROWSERS_PATH` and `PUPPETEER_CACHE_DIR` do not move it. Deleting the probe's directory leaves the store behind - 933 MB from two monorepo installs.

**What Happened**: Lane cdp1's probe on chat2 put Node, its npm and corepack caches, the browsers and the framework trees under `~/crane-work/cdp1-probe/`. The cleanup check (`find ~ -maxdepth 3 -newer <probe script>`) found `~/Library/pnpm` and `~/.local/state/pnpm`, both made by the Svelte and Vue installs; they were deleted with the probe directory.

**Fix**: Export `npm_config_store_dir=$ROOT/pnpm-store` beside the other cache variables before any `pnpm install`, and before ending a probe list what it created in the home directory: `find ~ -maxdepth 3 -newer <a file the probe made first> -not -path '*/crane-work/*'`.

**Takeaway**: **Point every package manager's store into the scratch directory, and prove the cleanup with a `-newer` search of the home directory - pnpm's store is not where its cache variables say.**
