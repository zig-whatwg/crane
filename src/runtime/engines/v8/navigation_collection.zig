//! The collection after a main frame's navigation: a V8 BUILD option,
//! `-Dv8-navigation-collection-mb` (declared by engine_build.zig).
//!
//! When a page navigates, what the page it left held is garbage, and V8 is
//! told so as Blink tells it: Isolate::ContextDisposedNotification, from the
//! old realm's end (protocol_realms.zig `notifyContextDisposed`; Blink's
//! LocalWindowProxy::DisposeContext -> V8GCForContextDispose::
//! NotifyContextDisposed, third_party/blink/renderer/bindings/core/v8/
//! v8_gc_for_context_dispose.cc:65-91, Chromium 157.0.8103.50). V8 15.7 does
//! not collect for it: with its preconfigured old generation - Chrome's
//! default - the notice resets no allocation limit and only tells the memory
//! reducer, whose first collection comes 30 s later (src/heap/heap.cc:
//! 1795-1820; flag gc_memory_reducer_start_delay_ms). So pages left one
//! after another stay until V8's own limit is reached - 64 MB of heap and
//! reported external memory, which ten documentation pages in one tab do not
//! reach: they ended at 103 MB of footprint where V8 13.1, which reset its
//! limits at the notice and collected every other page, ended at 75.
//!
//! Blink has one more step at that point, for a device short of memory
//! (v8_gc_for_context_dispose.cc:69-87, Android): when the page being left
//! used much memory - OomInterventionImpl::Check found the renderer near its
//! limits and called V8GCForContextDispose::SetForcePageNavigationGC
//! (third_party/blink/renderer/controller/oom_intervention_impl.cc:164-166),
//! "so that the memory usage of the two pages would not overlap"
//! (v8_gc_for_context_dispose.h:56-59) - and the main frame will be reused
//! (WindowProxy::kFrameWillBeReused), it sends V8 a critical memory-pressure
//! notice, once, at the main frame's context disposal.
//!
//! This is that step, for a build configured for little memory:
//!
//!   - WHEN: a top-level realm ended because a navigation gave its navigable
//!     a new Window (its WindowProxy was handed on: the frame is reused).
//!     Never for a frame's realm, a page that closed, a tab or a Browser
//!     that ended - nothing is reused there - and never for a page the
//!     back/forward cache keeps, whose realm does not end.
//!   - IF: V8's heap then holds at least the threshold - Crane's "the page
//!     being left used much memory". What is measured is V8's own figure,
//!     v8::HeapStatistics used_heap_size + external_memory: the size of the
//!     objects in its heap, live or not yet collected, plus its ArrayBuffer
//!     backing stores. (Not the external memory Crane reports for the DOM,
//!     which V8 counts toward its own limit and HeapStatistics does not
//!     show: the threshold was measured without it. A page heavy in DOM and
//!     light in script reaches the threshold late; V8's own limit, 64 MB of
//!     heap plus that reported memory, is the backstop for those.)
//!   - WHAT: one critical memory-pressure notice (protocol_agents.zig
//!     `notifyMemoryPressure`): V8 collects everything, the finalizers of
//!     what it found dead run, the trees they queued are torn down.
//!   - WHERE: the agent's next engine-task step (worker_realm.zig
//!     `runEngineTasks`), not inside the realm's end as Blink's
//!     DisposeContext sends it: Crane's finalizers and queued teardowns may
//!     not run with a DOM algorithm on the stack, and by then the old
//!     realm's context is weak, so the collection takes the page that was
//!     left.
//!   - ONCE per disposal; a critical notice the host sends in between (a
//!     Browser's own, at a page's end) pays it.
//!
//! The threshold is the build's, in megabytes:
//!
//!     -Dv8-navigation-collection-mb=<n>     0: never
//!
//! Not given: `default_mb`, 16, when the build's young generation is limited
//! (young_generation.zig: the default, 8 MB semispaces - the configuration
//! for little memory), and never when the young generation is V8's own
//! (-Dv8-young-generation-mb=0: a desktop build, where Chrome sends nothing
//! but the disposal notice).
//!
//! Measured (lane v8up b7, chat.local, the 8 MB default, x7 alternating; end
//! memory in MB and time per navigation, against no collection):
//!
//!   | threshold      | load.news  | load.docs   | load.app   | page-growth | time          |
//!   |----------------|------------|-------------|------------|-------------|---------------|
//!   | never          | 55.6       | 103.2       | 79.4       | 64.4        |               |
//!   | 32 MB          | 55.6       | 105.2       | 79.5       | 64.3        | never reached |
//!   | 16 MB          | 33.8       | 61.5        | 46.9       | 41.0        | +0.3 to +2.2% |
//!   | every disposal | 23.6       | 39.3        | 28.3       | 24.6        | +7.6 to +21%  |
//!   | main, V8 13.1  | 48.8       | 74.9        | 56.0       | 69.5        |               |
//!
//! At 16 MB one notice is sent in about ten pages, 2.4 to 7 ms each.

const std = @import("std");
const adapter_options = @import("adapter_options");
const young_generation = @import("young_generation.zig");

/// THE DEFAULT threshold, megabytes, for a build whose young generation is
/// limited and that does not say. One constant.
pub const default_mb: u32 = 16;

/// What this build was given: `-Dv8-navigation-collection-mb` (null: not
/// given).
pub const requested_mb: ?u32 = adapter_options.navigation_collection_mb;

/// This build's threshold, in bytes of the objects in V8's heap plus its
/// ArrayBuffer backing stores; null: no collection is sent after a
/// navigation.
pub const threshold: ?usize = thresholdFor(requested_mb, young_generation.limit != null);

/// The threshold of a build given `requested` megabytes (null: not given; 0:
/// never) whose young generation is limited or not.
pub fn thresholdFor(requested: ?u32, young_generation_limited: bool) ?usize {
    const megabytes = requested orelse (if (young_generation_limited) default_mb else return null);
    if (megabytes == 0) return null;
    return @as(usize, megabytes) * 1024 * 1024;
}
