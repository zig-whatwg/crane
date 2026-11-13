# Workflow: The V8 Crane links is not the V8 source checkout beside it

**Date**: 2026-10-04
**Status** (2026-11-13, perf round 7): the paths below are 13.1.203's, and since the V8 15.7 port (main 58da4933037) NOTHING links them. The linked V8 is 15.7.112.43, a directory of its own: headers `jsengines/v8/15.7.112.43/include/` (its `v8-version.h` is the linked version), archives `jsengines/v8/15.7.112.43/out/static/obj/` (`tools/v8_archives.zig`). `jsengines/v8/include/v8-version.h` and `jsengines/v8/out/static` still exist and still say 13.1.203: round 6's build script read that header for a console's pin, and would have published round 7's V8 15.7 console as `v8=13.1.203.0`. The takeaway holds with the new path, and with one more step: where a version is recorded (a pin, a BUILD_INFO), check it against the binary's own bytes (`LC_ALL=C grep -a -c -F 15.7.112.43 <binary>`: 2 in a 15.7 console, 0 in a 13.1 one).
**Lesson**: `jsengines/v8/v8/` (the full source checkout) is V8 14.6; the prebuilt monolith Crane links, and the headers it compiles against (`jsengines/v8/include/`), are 13.1.203. A flag, a builtin or an API read from the source checkout may not be what runs.

**Why**: The checkout is there to read V8's design and contracts; the prebuilt `jsengines/v8/out/static/obj/libv8_monolith.a` was built months earlier from an older revision. Nothing in the tree says which is which except `v8-version.h` in each.

**What Happened**: The binding batch's brief said "V8 13.1 ships js_float16array (flag-definitions.h:347, JAVASCRIPT_SHIPPING_FEATURES_BASE)" - true of the 14.6 checkout's flag-definitions.h. In 13.1, Float16Array, Math.f16round and DataView.getFloat16 are behind `--js-float16array` (shipping from 13.5), so the global had no Float16Array. `strings -a libv8_monolith.a | grep js_float16array` confirmed the flag exists in the linked build; adding it to RUNTIME_V8_FLAGS (and so to SNAPSHOT_V8_FLAGS) installed it.

**Fix**: Before relying on a V8 feature or flag, read `jsengines/v8/include/v8-version.h` (the linked version), and check the archive itself (`strings -a jsengines/v8/out/static/obj/libv8_monolith.a | grep <flag>`) rather than the checkout's sources.

**Takeaway**: **Read V8's design from the checkout, but its behaviour from the version you link: `jsengines/v8/include/v8-version.h` and the monolith, not `jsengines/v8/v8/`.**
