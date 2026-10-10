# Architecture: A reporting observer task is weak, but registration is strong

**Date**: 2026-10-09
**Lesson**: Determine each holder's browser lifetime separately: ReportingObserver registration keeps its target alive, while a queued notification does not keep a disconnected target alive.

**Why**: Treating all pending tasks as strong holders would change observable behavior after disconnect and garbage collection. Conversely, making registration weak would lose callbacks while an observer is still active.

**What Happened**: Reporting's specification describes a global notification task. Reading the engines exposed two independent differences. Blink and WebKit queue a task per observer and invoke its callback even after takeRecords emptied its queue; Gecko skips an empty queue. For lifetime, Blink uses WrapWeakPersistent for the queued task, Gecko only notifies registered observers, and WebKit keeps the task's observer alive. All three keep registered observers alive and synchronously append buffered reports during observe.

**Fix**: Follow the majority independently for scheduling and lifetime. Retain registered observers with keepPlatformObjectAlive, remove that retention on disconnect, and queue a slab-generation Link as the weak task target. Check the Link before reading the observer. Root a live target only while executing its callback. Keep the reports themselves as owned native records, converting them to script values when delivered. Test registration followed by dropping script references and GC, and both disconnect cases (script retains the observer, or drops it), as well as an empty-array callback after takeRecords.

Sources: [Blink ReportingObserver](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/frame/reporting_observer.cc), [WebKit ReportingObserver](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/Modules/reporting/ReportingObserver.cpp), [Gecko ReportingObserver](https://github.com/mozilla/gecko-dev/blob/master/dom/reporting/ReportingObserver.cpp). Integrator ruling: codex-csp3 ANSWER Q8.

**Takeaway**: **A weak generation link is correct when weakness is the specified browser behavior; it is not a substitute for a required strong holder.**
