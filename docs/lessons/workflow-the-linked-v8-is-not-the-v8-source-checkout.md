# Workflow: The V8 Crane links is not the V8 source checkout beside it

**Date**: 2026-10-04
**Lesson**: `jsengines/v8/v8/` (the full source checkout) is V8 14.6; the prebuilt monolith Crane links, and the headers it compiles against (`jsengines/v8/include/`), are 13.1.203. A flag, a builtin or an API read from the source checkout may not be what runs.

**Why**: The checkout is there to read V8's design and contracts; the prebuilt `jsengines/v8/out/static/obj/libv8_monolith.a` was built months earlier from an older revision. Nothing in the tree says which is which except `v8-version.h` in each.

**What Happened**: The binding batch's brief said "V8 13.1 ships js_float16array (flag-definitions.h:347, JAVASCRIPT_SHIPPING_FEATURES_BASE)" - true of the 14.6 checkout's flag-definitions.h. In 13.1, Float16Array, Math.f16round and DataView.getFloat16 are behind `--js-float16array` (shipping from 13.5), so the global had no Float16Array. `strings -a libv8_monolith.a | grep js_float16array` confirmed the flag exists in the linked build; adding it to RUNTIME_V8_FLAGS (and so to SNAPSHOT_V8_FLAGS) installed it.

**Fix**: Before relying on a V8 feature or flag, read `jsengines/v8/include/v8-version.h` (the linked version), and check the archive itself (`strings -a jsengines/v8/out/static/obj/libv8_monolith.a | grep <flag>`) rather than the checkout's sources.

**Takeaway**: **Read V8's design from the checkout, but its behaviour from the version you link: `jsengines/v8/include/v8-version.h` and the monolith, not `jsengines/v8/v8/`.**
