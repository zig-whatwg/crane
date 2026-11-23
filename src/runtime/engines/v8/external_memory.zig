//! [external_memory]: the V8 adapter tells its isolate how the host's native
//! memory its objects keep alive changed (engine.AgentOptions.
//! external_memory; runtime.gc.ExternalMemory - a Browser's DOM, on its
//! window agent).
//!
//! V8 schedules collections by its own heap's growth. A wrapper is a few
//! dozen bytes of that heap and holds a native tree alive, so a script that
//! makes and drops trees allocates almost nothing V8 sees and runs no
//! collection at all: 650 dropped clones of an 840-node tree kept 548,150
//! nodes, 1.7 GB, with 5 MB of V8 heap in use (lane perf1, gc_bench). Told
//! the change, V8 counts it toward its global allocation limit: every 128 KB
//! of growth it checks the limits and, once they are reached, starts
//! incremental marking - which advances in the marking job's task, run when
//! the embedder pumps the platform (the event loop's engine-task step) - and
//! it collects at once past its heap limit or when marking runs and the
//! limit is overshot by a large margin (V8 15.7 src/heap/heap.cc,
//! Heap::UpdateExternalMemory). Blink reported its DOM the same way before
//! its unified heap: V8GCController::reportDOMMemoryUsageToV8 passed the
//! change of the DOM partition's size to Isolate::
//! AdjustAmountOfExternalAllocatedMemory after every task (Chromium 45,
//! Source/bindings/core/v8/V8GCController.cpp); an embedder now reports
//! through a v8::ExternalMemoryAccounter, one per reporting owner - here the
//! agent.
//!
//! The safe points are the adapter's: the binding exit back into script that
//! brings the agent's DOM-algorithm depth to zero (dom_algorithm.zig, where
//! a collection the report starts meets no DOM frame below), and each
//! microtask checkpoint outside a DOM algorithm - after every task, Blink's
//! point - and, since lane mem1, a binding's return into the script of the
//! innermost callback invocation, with no drain after it
//! (`reportInCallbackStep`). A report is made only once the figure moved
//! `report_step` (128 KB, V8's own step), which the host flags where the
//! figure moves
//! (ExternalMemory.due) and owes on the agent's queue
//! (DeferredTeardown.Owed.report): the binding exit pays nothing for it -
//! its one check of what the queue owes, the same compare as before, covers
//! it, and the queue's report steps run the report there. The agent's end
//! takes back all it reported.

const std = @import("std");
const runtime = @import("runtime");
const ffi = @import("ffi.zig");
const isolate_templates = @import("isolate_templates.zig");

const ExternalMemory = runtime.gc.ExternalMemory;
const Storage = isolate_templates.IsolateTemplates;

/// createAgent: the agent's figure, claimed for its thread, on its isolate,
/// and reported at its queue's safe points (the queue's report steps, which
/// the binding exit's check of what the queue owes reaches), through the
/// agent's ExternalMemoryAccounter. A storage or accounter that cannot be
/// made (out of memory) leaves the agent unreported - V8 then sees its own
/// heap alone, as before.
pub fn install(isolate: *ffi.Isolate, memory: ?*ExternalMemory, queue: ?*runtime.gc.DeferredTeardown) void {
    const given = memory orelse return;
    const storage = isolate_templates.storageFor(isolate) orelse return;
    const accounter = ffi.v8_ExternalMemoryAccounter_New() orelse return;
    storage.external_memory = given;
    storage.external_reported = 0;
    storage.external_isolate = isolate;
    storage.external_accounter = accounter;
    if (queue) |q| q.report_steps = .{ .run = reportStep, .run_in_callback = reportInCallbackStep, .data = storage };
    given.claim(queue);
}

/// The queue's report steps: its safe point owed a report.
fn reportStep(data: ?*anyopaque) void {
    const storage: *Storage = @ptrCast(@alignCast(data orelse return));
    reportIfMoved(storage);
}

/// The queue's report steps INSIDE A CALLBACK (lane mem1): a binding
/// returned into the script of the innermost callback invocation and a
/// report is owed. Most of a page's script runs inside callbacks, whose
/// bindings never return at depth zero, so a DOM-heavy callback that
/// allocates little on V8's heap told V8 nothing until it returned, and
/// nothing collected the wrappers it dropped. Blink's unified heap tells V8
/// at each allocation, at any depth (15.7.112.43 src/heap/cppgc-js/
/// cpp-heap.cc:1055-1107: every 128 KB, StartIncrementalMarkingIfAllocation
/// LimitIsReached and, while marking, finalize on a large overshoot or
/// advance). Here: at the binding's return, within one binding call of the
/// growth - never where the figure moves, inside a DOM algorithm, where a
/// collection's walk could read a tree in the middle of its mutation.
///
/// The collection the report may start or finish is the one any allocation
/// inside the callback can already start: what it runs of Crane's is
/// bookkeeping (v8_wrapper.cpp `v8_ExternalMemoryAccounter_UpdateNoDrain`).
/// Unlike the depth-zero report, NOTHING is drained after it: what its
/// collection queued runs by the fresh rule at the next binding return.
/// False - still owed, for the next return - beneath a running finalizer
/// or with the returning binding's exception pending.
fn reportInCallbackStep(data: ?*anyopaque) bool {
    const storage: *Storage = @ptrCast(@alignCast(data orelse return true));
    const memory = storage.external_memory orelse return true;
    if (!memory.due) return true;
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(storage.external_isolate orelse return true));
    const accounter: *ffi.ExternalMemoryAccounter = @ptrCast(storage.external_accounter orelse return true);
    if (!ffi.v8_Isolate_InCallbackReportOpen(isolate)) return false;
    // As `report`: the figure is recorded told before V8 is, because a
    // collection the report runs ends its marking with this figure
    // (`endOfMarking`).
    const live = memory.live;
    const change = @as(i64, @intCast(live)) - @as(i64, @intCast(storage.external_reported));
    storage.external_reported = live;
    memory.markReported(live);
    ffi.v8_ExternalMemoryAccounter_UpdateNoDrain(accounter, isolate, change);
    return true;
}

/// The agent's end, its isolate entered: V8's count goes back to what it was
/// before the agent reported anything, and the figure is no longer the
/// agent's.
pub fn uninstall(isolate: *ffi.Isolate) void {
    const storage = isolate_templates.getTemplateStorage(isolate) orelse return;
    const memory = storage.external_memory orelse return;
    if (storage.external_accounter) |raw| {
        const accounter: *ffi.ExternalMemoryAccounter = @ptrCast(raw);
        ffi.v8_ExternalMemoryAccounter_Delete(accounter, isolate, storage.external_reported);
    }
    storage.external_reported = 0;
    storage.external_accounter = null;
    if (memory.queue) |queue| queue.report_steps = null;
    memory.release();
    storage.external_memory = null;
    storage.external_isolate = null;
}

/// A safe point on the agent's thread, its isolate entered: tell V8 once the
/// figure moved `report_step` from what it was last told (the host's flag,
/// set where the figure moves).
pub inline fn reportIfMoved(storage: *Storage) void {
    const memory = storage.external_memory orelse return;
    if (!memory.due) return;
    report(storage, memory);
}

/// `reportIfMoved` for a caller with the isolate.
pub fn reportIfMovedOn(isolate: *ffi.Isolate) void {
    const storage = isolate_templates.getTemplateStorage(isolate) orelse return;
    reportIfMoved(storage);
}

/// [external_memory_at_collection]: the end of a full collection's marking,
/// in its atomic pause (node_wrappers.zig `markedCallback`), the node
/// wrappers found dead in it recorded in `dead` and none of their references
/// released yet. V8 computes its next limits when this collection ends, from
/// what it then believes is alive (15.7.112.43 src/heap/heap.cc:2595 takes
/// the sizes, :1604 RecomputeLimits), and the trees those wrappers were the
/// last to keep are in the figure until the agent's next safe point releases
/// them: a limit computed with them ratchets (lane dm1's design,
/// tmp/plans/dom-memory-figure-design.md 2.1: 105.7 MB after the parser
/// page's first collection, 47 MB alive). So the owner of the counts is
/// asked which trees die with these wrappers (runtime.lifetime.dyingWith:
/// their bytes leave the figure there), and V8 is told the figure as it
/// stands now - with ONE decrease, which starts no collection
/// (v8_ExternalMemoryAccounter_Decrease). That also tells it of the trees
/// the counts decided dead since the last report. Growth since the last
/// report is not told here: an increase may collect, and waits for the
/// next safe point as always.
///
/// Blink's nodes are on V8's C++ heap, whose marked bytes are the size V8
/// reads there; JavaScriptCore sums what each visited wrapper keeps
/// (engine.capabilities.external_memory_at_collection has both). `tracer`
/// carries this collection's visited set for the owner's dedupe; nothing is
/// marked through it.
pub fn endOfMarking(isolate: *ffi.Isolate, dead: []const runtime.lifetime.DeadWrapper, tracer: *@import("node_wrappers.zig").Tracer) void {
    const storage = isolate_templates.getTemplateStorage(isolate) orelse return;
    const memory = storage.external_memory orelse return;
    _ = runtime.lifetime.dyingWith(memory, dead, tracer);
    const live = memory.live;
    if (storage.external_reported <= live) return;
    const accounter: *ffi.ExternalMemoryAccounter = @ptrCast(storage.external_accounter orelse return);
    const fell = storage.external_reported - live;
    storage.external_reported = live;
    memory.markReported(live);
    ffi.v8_ExternalMemoryAccounter_Decrease(accounter, isolate, fell);
}

/// The references of every node wrapper the agent's collections found dead
/// are released (node_wrappers.zig: the drain emptied its list): what a
/// collection's end of marking predicted dead and no tree's queueing took
/// is back in the figure (ExternalMemory.settlePredictions), and V8 hears
/// of it at the next report.
pub fn releasesDone(isolate: *ffi.Isolate) void {
    const storage = isolate_templates.getTemplateStorage(isolate) orelse return;
    const memory = storage.external_memory orelse return;
    _ = memory.settlePredictions();
}

/// What V8 was last told of `isolate`'s figure (tests).
pub fn reportedOn(isolate: *ffi.Isolate) usize {
    const storage = isolate_templates.getTemplateStorage(isolate) orelse return 0;
    return storage.external_reported;
}

noinline fn report(storage: *Storage, memory: *ExternalMemory) void {
    // The safe points run on the isolate's thread with it entered: the
    // binding's callback, the checkpoint's EnteredIsolate.
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(storage.external_isolate orelse return));
    const accounter: *ffi.ExternalMemoryAccounter = @ptrCast(storage.external_accounter orelse return);
    const live = memory.live;
    const change = @as(i64, @intCast(live)) - @as(i64, @intCast(storage.external_reported));
    storage.external_reported = live;
    memory.markReported(live);
    ffi.v8_ExternalMemoryAccounter_Update(accounter, isolate, change);
}
