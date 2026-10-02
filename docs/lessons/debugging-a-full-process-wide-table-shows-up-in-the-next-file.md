# Debugging: A full process-wide table shows up in the next file, as a wrong prototype

**Date**: 2026-10-02
**Lesson**: The template registry was one 8,192-entry table for the whole
process, and every isolate registers ~1,260 templates. A file with many shared
workers alive filled it; every later registration was dropped with an error
line, and the NEXT file's dedicated worker built a second template for each
constructible interface it looked up - so its XMLHttpRequestEventTarget.prototype
did not inherit from its EventTarget.prototype.

**Why**: a dropped registration is a lookup miss later. `materializeInterfaceObject`
and the parent lookup in `createTemplateCore` both fall back to
`createTemplate`, and for an interface with a constructor that is
`createTemplateFresh` - never cached - so the parent the child inherits from
and the parent installed on the global were two templates.

**What Happened**: xhr/idlharness.any.worker.html passed 153/160 alone and
151/160 after workers/modules/shared-worker-options-credentials.html in one
runner process. The batch's first two hypotheses (another isolate's generation
bump discarding a live isolate's template storage; V8Interface's static cache
serving a reused isolate address) were both disproved by instrumented runs.
The cause was in the baseline sweep's log all along: 408,958 lines of
`template registry full (8192 entries): dropping '<Interface>'` - and 5,058 of
them in the two-file run's own log, 0 alone. Nobody had grepped for it.

**Fix**: the registry is a map per isolate (name -> template) in a table of
isolates guarded by a mutex held only for a find, insert or removal; it grows,
and an ended isolate's map goes with it (clearForIsolate). tests/v8
template_registry_isolation_test.zig pins 12 isolates alive at once (red on the
fixed table), isolates made and ended in sequence, and two threads making and
ending isolates at once (crashed without the lock).
crane/td-many-workers-prototype-chains.html: 32 shared workers then a
dedicated worker - 3 wrong chains and 5,330 drops before, none after.

**Takeaway**: **Before theorising about a result that depends on the previous
file, grep the sweep log for every error line the process printed - a logged
"dropping" is a defect, not noise. And never give a per-isolate cache a fixed
process-wide capacity.**
