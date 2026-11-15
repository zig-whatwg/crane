# Workflow: Zig 0.17 resolves a child's argv[0] with the parent's PATH, not the child's

**Date**: 2026-11-14
**Lesson**: `std.process.run` / `spawn` with `environ_map` gives the child that environment, but argv[0] is looked up in the PARENT's PATH; run a pinned tool by its absolute path, and let its `#!/usr/bin/env node` find the pinned interpreter through the child's PATH.

**Why**: Zig 0.17's `SpawnOptions.environ_map`: "The PATH value from here is not used to resolve `argv[0]`; that resolution always uses parent environment." A tool that puts a pinned Node's bin first on the child's PATH and runs `npm` by name gets the host's npm (or none) - and a different Node than the manifest pins, with no error.

**What Happened**: fw_matrix (lane fw1 b4) runs `npm ci`, `npm run babel:tests` and jQuery's `jtr serve` under Node 24.22.3 fetched by checksum. It runs `<node>/bin/npm` and `<tree>/node_modules/.bin/jtr` by absolute path (a manifest command is a path below the tree, never a bare name), with `<node>/bin` leading the child's PATH: both are `#!/usr/bin/env node` scripts, and `env` resolves `node` in the child's environment, so the pinned Node runs them. A test pins it: a stand-in server script reports the PATH it was given.

**Fix**: In a host tool, build argv[0] as an absolute path; put the pinned bin directory first on the child's PATH for what the child itself looks up; refuse a bare command name in the manifest.

**Takeaway**: **In Zig 0.17, `environ_map` does not choose the program: name it by absolute path, and use the child's PATH only for what the child resolves.**
