# Architecture: A workaround outlives its premise

**Date**: 2026-09-29
**Lesson**: `v8_PatchEventInstanceOf` replaced `Event[Symbol.hasInstance]` on every realm restored from the snapshot, because "V8 snapshots don't preserve prototype identity". By 2026-09 they did, and the patch's own lookup (a WrapperTypeInfo in internal field 1) found null for every event, so `new Event("x") instanceof Event` was false - and so was every event the engine dispatched.

**Why**: A workaround that answers from side data (type info in an internal field) instead of the ordinary mechanism (the prototype chain) keeps answering after the original bug is gone - and when the side data changes shape, it answers wrong for everything. Nothing re-checked the premise: the no-snapshot path, which never patched, was correct all along, and nobody compared the two.

**What Happened**: Found while fixing forms: button-events.html's submit listener asserted `evt instanceof Event` and failed for a trusted SubmitEvent. A probe printed the chain (`FocusEvent > UIEvent > Event > Object`, `Object.getPrototypeOf(UIEvent.prototype) === Event.prototype` true) next to `instanceof Event` false, and `Event` owned a `Symbol.hasInstance`. The callback also wrote an unguarded fprintf per instanceof and matched a blocklist of event names (SubmitEvent, FormDataEvent, ToggleEvent were missing). 40 worklist files assert instanceof on events. The Window and Document patches rest on the same premise, and are wrong across realms: a frame's window is instanceof the top's Window on the snapshot path.

**Fix**: Delete the patch (ac4ad6457). Crane test crane/events-instanceof.html asserts instanceof for constructor-made and engine-dispatched events in the main realm on both startup paths, a frame's realm (its own Event, not the top's) and a dedicated worker; crane/window-document-instanceof.html is the red test for the Window/Document removal.

**Takeaway**: **When a workaround answers from side data instead of the ordinary mechanism, re-measure its premise against the path that never had it - run the snapshot and no-snapshot paths side by side.**
