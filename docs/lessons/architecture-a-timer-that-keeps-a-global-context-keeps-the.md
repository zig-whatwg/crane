# Architecture: A timer that keeps a Global<Context> keeps the whole page

**Status (2026-09-25)**: fixed - `V8TimerContextData.release` disposes the handler, arguments and context.

**Date**: 2026-09-22
**Lesson**: `V8TimerContextData` holds the handler and the current context as owned handles and nothing disposes them, so every page that sets a timer stays in memory - ~28 MB per file in long sweeps until V8 hits its heap limit, and the OOM crash is charged to whichever file is loading.

**Takeaway**: **Growth that crosses pages is a leaked handle to something the next page does not need; a file that crashes only after N others is accumulated state, not the file.**
