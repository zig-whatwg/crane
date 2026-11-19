# Architecture: A rendering step reads its document state; only the feature's first write makes it

**Date**: 2026-11-18
**Lesson**: A step installed into "update the rendering" runs for every document on every rendering opportunity, so an accessor it calls that makes state on demand (an ensure-style getter) makes that state for every rendered document - silently, and at a moment the event loop picks.

**Why**: Lane css1's view transition state lives in the style engine's rare record (StyleEngine.Rare.view_transitions). The one accessor, viewTransitionState(), called engine.ensureRare() - right for startViewTransition(), which must make the state, but update-the-rendering step 18 (perform pending transition operations) and the activeViewTransition getter called it too.

**What Happened**: tests/html/cv1_random_provider_test.zig pins Rare lazy (engine.rare == null after style reads). It failed once on the macOS gate and passed twice alone: whether a rendering opportunity fell between two of its page.run calls decided whether step 18 had made Rare. Every rendered document paid a Rare allocation from its first frame on.

**Fix**: Two accessors. viewTransitionState() reads (null when no rare record exists); ensureViewTransitionState() makes it, called from start() alone; setViewTransitionSheet(null) returns without making Rare. The red test (tests/html/css1_view_transition_state_lazy_test.zig) calls the step and the getter directly and asserts engine.rare == null, so it fails every run, not on timing.

**Takeaway**: **Anything a per-frame step or a getter calls must be read-only; make lazy state at the feature's first write, and test the step directly - a timing-dependent allocation shows up as some other test's flake.**
