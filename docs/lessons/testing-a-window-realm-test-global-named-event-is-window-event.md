# Testing: In a Window realm, a test global named `event` is `window.event`

**Date**: 2026-09-30
**Lesson**: A tests/v8 test that ran `globalThis.event = new AnimationEvent(...)` and later evaluated `event` threw: in a realm whose global is a Window, `event` is the legacy current-event attribute (`window.event`), not the script's variable.

**Why**: Window's IDL attributes are accessors on the global. Assigning to one does not make a plain data property, and reading it runs Window's getter. The test's Window is a bare host Window, so the getter took paths a page never takes.

**What Happened**: the first red run of the inner-invoke step 9 test failed at `evalOwned(w, "event")` with ExceptionReported - the right test, the wrong reason. A red for the wrong reason is not a red, so the run was repeated after renaming the global to `animationEvent`. That cost one full `zig build test -Dspec=v8` (about 25 minutes on chat).

**Fix**: name test globals after what they hold, and never after a Window member (`event`, `name`, `status`, `length`, `origin`, `top`, `parent`, `self`, `opener`, ...).

**Takeaway**: **In a Window realm, check a test global's name against Window's own attributes. A red run is only red if it fails at the assertion you wrote.**
