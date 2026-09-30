# Workflow: crane-remote.sh rewrites every "zig build" substring, `zig build-exe` included

**Date**: 2026-09-30
**Lesson**: `tmp/remote/crane-remote.sh` adds the shared cache by textual substitution (`${cmd//zig build/zig build --cache-dir $HOME/crane-cache}`), so `zig build-exe ...` reaches chat as `zig build --cache-dir ~/crane-cache-exe ...` and fails as an unknown build option.

**Why**: The substitution matches the substring, not the command word. `zig build-exe`, `zig build-lib` and `zig build-obj` all begin with it. The rewrite also names a cache directory, `~/crane-cache-exe`, that nothing else uses.

**What Happened**: the wptsite lane needed the site generator as a standalone binary, to run it here against the main checkout's real data. `crane-remote.sh wptsite 'zig build-exe -OReleaseSafe tools/wpt_site/generate.zig ...'` failed with `unrecognized argument: '-OReleaseSafe'`, because the build runner was handed the flags meant for `build-exe`.

**Fix**: stop the substitution from seeing the word. Use `Z=zig; $Z build-exe -OReleaseSafe tools/wpt_site/generate.zig -femit-bin=zig-out/bin/wpt_site`, then `scp` the binary back. Alternatively, build through a `zig build <step>` that installs it. The helper itself could match `zig build ` with a trailing space, or only a whole word; that is the integrator's file.

**Takeaway**: **The remote helper edits your command as text. Anything that begins with "zig build" is rewritten, so hide `build-exe` behind a variable, or use a build step.**
