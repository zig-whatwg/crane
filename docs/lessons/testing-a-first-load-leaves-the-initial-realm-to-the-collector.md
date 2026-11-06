# Testing: A page's first load leaves its initial about:blank realm to the collector - settle it before a baseline

**Date**: 2026-11-05
**Lesson**: Once a page's first load gave it a new Window (its initial about:blank is opaque), tests that counted live instances or global handles after `loadHTML` read numbers that dropped mid-test as the replaced realm was collected and torn down.

**Why**: HTML "create and initialize a Document object" step 7 makes a new Window unless the initial about:blank is same origin-domain with the new document; a host-made traversable's never is. The old realm ends when the collector takes it, and its instances are freed in slices from the event loop (runtime.gc.DeferredTeardown) - after the test took its baseline.

**What Happened**: lane loadpath1. refcount_retention D1 read 91 of 97 nodes alive (the baseline included the old document's html/head/body and Window), window_index_iframe_lookup read +480 handle bytes in the measured phase than in the control - the control phase had the old realm's handles freed under it.

**Fix**: the helpers (tests/html/refcount_probe.zig Page.open, refcount_holders_helpers.zig Page.open) collect and turn the event loop three times after the load, before anything is counted.

**Takeaway**: **A test that counts what is alive must start from a settled heap: after any load that replaces a Window, collect AND turn the event loop (the teardown runs between tasks) before the baseline.**
