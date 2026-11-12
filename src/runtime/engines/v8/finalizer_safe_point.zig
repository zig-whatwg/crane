//! [finalizer_safe_point]: the binding exit back into script is the agent's
//! safe point for the finalizers of its collected wrappers inside a task.
//!
//! V8's second pass runs no Zig finalizer - 15.7 runs the pass under
//! DisallowJSObjectModification, and a finalizer is an instance's teardown,
//! which may write a JS object - so the pass only queues the record on its
//! agent (v8_wrapper.cpp `queueFinalizer`), and the agent runs it at a safe
//! point (`runQueuedFinalizers`). The pump and a forced collection's return
//! are safe points between tasks. ONE long script reaches neither: V8 posts
//! a collection's second pass as a task (15.7.112.43 src/handles/
//! global-handles.cc:892-901) and the next collection runs a pending pass
//! first (src/heap/heap.cc:1509-1511), so the finalizers of everything the
//! script dropped waited, queued, each keeping its native state, for the
//! task's end (300,000 dropped Events in one loop: 392 MB instead of 168 MB,
//! lane v8up b6).
//!
//! The safe point such a script does reach is a binding's return into it
//! with no DOM algorithm below - the exit that already runs what the agent's
//! deferred teardown queue owes (dom_algorithm.zig leaveToScript ->
//! runtime.gc.DeferredTeardown.leaveAlgorithmToScript). So:
//!
//! - the second pass sets ONE BIT of the queue's owed word
//!   (DeferredTeardown.Owed.finalizers), through a pointer this file gives
//!   the isolate's record (v8_Isolate_SetFinalizersOwed). A store: the pass
//!   still calls nothing of Zig's;
//! - the queue's finalizer steps (`step`, installed here beside the report
//!   steps external_memory.zig installs) run the queued finalizers at the
//!   exit that finds the bit, before the frees and the report it also owes.
//!
//! A binding exit with nothing owed is unchanged: its one check of what the
//! queue owes - the same compare as before - covers this bit too.
//!
//! The browsers' precedent: Blink releases a dead wrappable's native state
//! inside the running script too. A wrappable is a cppgc object (Chromium
//! 157.0.8103.51 third_party/blink/renderer/platform/bindings/
//! script_wrappable.h:53, `class ScriptWrappable : public
//! v8::Object::Wrappable`; V8 include/v8-object.h:587, `class Wrappable :
//! public cppgc::GarbageCollected<Wrappable>`), its destructor is its
//! finalizer ("finalization is done at an arbitrary time after the object
//! becomes unreachable", platform/heap/BlinkGCAPIReference.md:70), and cppgc
//! sweeps lazily on the mutator's allocations: "Lazily sweep pages of this
//! heap. This is not exhaustive to limit jank on allocation." (V8
//! 15.7.112.43 src/heap/cppgc-internal/object-allocator.cc:251-296,
//! ObjectAllocator::TryRefillLinearAllocationBuffer ->
//! Sweeper::SweepForAllocationIfRunning, 500 us a time, :264-265), where the
//! sweep finalizes each dead object as it meets it (sweeper.cc:273-283
//! InlinedFinalizationBuilder::AddFinalizer -> HeapObjectHeader::Finalize,
//! heap-object-header.cc:27-39 -> the destructor). Crane's finalizers do
//! engine work a cppgc destructor may not, so they run where that is
//! allowed - the binding's return, not the allocation.
//!
//! Re-entrancy (v8_wrapper.cpp `runQueuedFinalizersInTask`):
//! - never at a non-zero DOM-algorithm depth: the steps run only from
//!   DeferredTeardown.runOwed, which only the outermost binding exit reaches;
//!   a binding that returns into script a native algorithm called returns
//!   at depth one and runs nothing, and neither does a callback's return;
//! - never beneath a finalizer: one that runs script, whose binding returns
//!   into it at depth zero, finds the drain on the stack and runs nothing;
//!   that drain takes what was queued meanwhile when the finalizer returns
//!   (cppgc: "Bail out for recursive sweeping calls. This can happen when
//!   finalizers allocate new memory.", sweeper.cc:1197-1211);
//! - never while the returning binding's exception is pending: the bit stays
//!   owed, and the next exit that returns normally runs them.

const runtime = @import("runtime");
const ffi = @import("ffi.zig");

const DeferredTeardown = runtime.gc.DeferredTeardown;

/// createAgent, on the agent's thread: `queue` - the agent's, the host's or
/// its own - is told when a second pass of `isolate` queues finalizers, and
/// runs them at its next binding exit into script. Null (an agent with no
/// queue): its finalizers run at the pump and at forced collections only.
pub fn install(isolate: *ffi.Isolate, queue: ?*DeferredTeardown) void {
    const q = queue orelse return;
    q.finalizer_steps = .{ .run = step, .data = isolate };
    ffi.v8_Isolate_SetFinalizersOwed(isolate, q.owedWord(), DeferredTeardown.Owed.finalizers_mask);
}

/// The agent's end, its isolate entered, before `queue` can go (a host's is
/// BORROWED until here; the agent's own is freed after its last
/// collections): no second pass stores into it from here on, and it owes no
/// finalizers - the agent's last forced collections run what is left.
pub fn uninstall(isolate: *ffi.Isolate, queue: ?*DeferredTeardown) void {
    ffi.v8_Isolate_SetFinalizersOwed(isolate, null, 0);
    const q = queue orelse return;
    q.finalizer_steps = null;
    q.owed.finalizers = false;
}

/// The queue's finalizer steps: a binding returned into script at depth zero
/// and finalizers are owed.
fn step(data: ?*anyopaque) bool {
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(data orelse return true));
    return ffi.v8_Isolate_RunQueuedFinalizers(isolate);
}
