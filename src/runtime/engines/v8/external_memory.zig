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
//! point. A report is made only once the figure moved `report_step` (128 KB,
//! V8's own step), which the host flags where the figure moves
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
    if (queue) |q| q.report_steps = .{ .run = reportStep, .data = storage };
    given.claim(queue);
}

/// The queue's report steps: its safe point owed a report.
fn reportStep(data: ?*anyopaque) void {
    const storage: *Storage = @ptrCast(@alignCast(data orelse return));
    reportIfMoved(storage);
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
