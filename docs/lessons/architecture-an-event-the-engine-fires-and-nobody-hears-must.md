# Architecture: An event the engine fires and nobody hears must still be freed

**Date**: 2026-09-24
**Lesson**: `Document.fireEvent`, `firePageShow` and `script_execution.fireAtScriptElement` dispatched their event and dropped it. The comment claimed it was "batch-freed with the rest at context teardown". Nothing sweeps a context's Instances.

**What Happened**: `CRANE_LEAK_TRACES=1` on `dom/nodes/Node-appendChild.html`: 3 leaks per page before the lifecycle commit, 6 after it (readystatechange twice, pageshow). Every page in a sweep paid them.

**Fix**: `runtime.Instance.releaseIfUnwrapped(generation)`, with the generation read when the event was made. A wrapper still in the cache owns the event. A slot whose generation moved on was collected during dispatch. Only an event nothing ever wrapped is freed. `defer Event.deinit` is never right for an event a listener can keep. `fireLoadEventOnIframe` did that, and `await new Promise(r => iframe.addEventListener("load", r))` keeps it.

**Not fixed**: `destroyChildContext` tears a child's wrapper cache down with `deinitWithoutCallbacks`. An object a frame's script wrapped (a `URLSearchParams`, an event a listener took) leaks its owned memory when the frame goes: about 5 allocations per popup in `open-features-negative-width-height.html`.

**Takeaway**: **Run one ordinary page under `CRANE_LEAK_TRACES=1` after any change that fires events.** A zero is cheap to keep and expensive to recover.
