# Testing: An uninstalled hook does not exercise its active path

**Date**: 2026-10-05

**Lesson**: A protocol hook's tests must install a real host before its active adapter branch is considered tested.

**Why**: An optional hook can switch the engine to a different construction path. Running the same WPT files with no hook only verifies the legacy branch, even when the new code compiles.

**What Happened**: HTMLConstructor's binding gate stayed green before the HTML owner installed the hook. Activation exposed eight failures in newtarget-customized-builtins.html: a primitive NewTarget.prototype kept Object.prototype instead of the interface prototype from NewTarget's realm. The active branch conditionally called the existing fallback helper after comparing the receiver with the active interface's prototype; that did not recognize the Object.prototype fallback described by the helper's own contract. The two existing prototype-get ordering failures were a separate, previously accepted deviation.

**Fix**: Test both uninstalled and installed hook paths. Include cross-realm customized built-ins, primitive prototypes, Proxy targets from both realms, and the ordinary object-prototype case. The HTML host must stay inside its declared steps; the adapter owns prototype resolution. This batch records the adapter defect for its owner rather than crossing the engine boundary.

**Integration follow-up (2026-10-06)**: The normal unit suite passed after activation, but file isolation exposed three node-tracing tests whose helper installed only the adapter's tree hooks. Their first `Document.createElement()` threw `InvalidStateError` because no earlier file had installed the DOM owners' hooks. Low-level tests that make platform objects without starting `crane.Process` must call `interfaces.process_hooks.startHooksForTest()` in their own setup. A later test's setup cannot supply an earlier test's preconditions.

**Takeaway**: **An inactive dependency can make a broad gate exercise the wrong branch; validate the installed contract together.**
