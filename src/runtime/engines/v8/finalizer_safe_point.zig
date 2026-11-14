//! [finalizer_safe_point]: the binding exit back into script is the agent's
//! safe point for the finalizers of its collected wrappers inside a task.
//!
//! No Zig finalizer runs inside V8's collector - 15.7 runs its weak
//! callbacks, both passes, under DisallowJSObjectModification, and a
//! finalizer is an instance's teardown, which may write a JS object - so the
//! collection's first pass only queues the record on its agent
//! (v8_wrapper.cpp `queueFinalizer`, "Why the first pass queues"), and the
//! agent runs it at a safe point (`runQueuedFinalizers`). The pump and a
//! forced collection's return are safe points between tasks. ONE long script
//! reaches neither, so the finalizers of everything the script dropped
//! waited, queued, each keeping its native state, for the task's end
//! (300,000 dropped Events in one loop: 392 MB instead of 168 MB, lane v8up
//! b6).
//!
//! The safe point such a script does reach is a binding's return into it
//! with no DOM algorithm below - the exit that already runs what the agent's
//! deferred teardown queue owes (dom_algorithm.zig leaveToScript ->
//! runtime.gc.DeferredTeardown.leaveAlgorithmToScript). So:
//!
//! - the first pass, as it queues a record, sets ONE BIT of the queue's
//!   owed word (DeferredTeardown.Owed.finalizers), through a pointer this
//!   file gives the isolate's record (v8_Isolate_SetFinalizersOwed). A
//!   store: the pass calls nothing of Zig's for it;
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
//! INSIDE A CALLBACK. Script a native algorithm calls - a timer callback,
//! an event listener, an observer - runs with that algorithm on the stack
//! for the whole callback (protocol.zig counts the invocation), so none of
//! its bindings returns at depth zero, and most of a page's script runs
//! there: the same loop inside a listener ended at 388 MB and stayed at
//! 373 MB after two forced collections. On main (V8 13.1) the second pass
//! ran those finalizers inside the callback, at any depth. What may run at
//! a binding's return into a callback's script is decided by construction,
//! not by type:
//!
//!   FRESH = the object was made by a script-called WebIDL constructor
//!   (`new X()`: the constructor trampoline created the instance and first
//!   wrapped it, in that one binding call) at or after the beginning of the
//!   innermost callback invocation still on the stack.
//!
//! Every DOM algorithm on the stack - the invocation's own, and all below -
//! has been suspended in its call into script since before a fresh object
//! existed, and has not run since: none of them holds a pointer to it. (A
//! pointer some binding has since stored in a longer-lived structure is the
//! question it already is at depth zero.) The agent's callback clock
//! (DeferredTeardown.Callbacks) ticks at every callback invocation; the
//! trampoline stamps the wrapper cache entry with it
//! (WrapperCache.setConstructed), and `runFresh` compares stamps with the
//! innermost invocation's tick. The default is the safe answer - not fresh,
//! wait for depth zero: a node (its wrapper's end only lets its reference
//! go; its tree is the queue's), an object an operation returned, one
//! wrapped while it was being constructed, one made before the innermost
//! callback began or outside any, the other kinds of finalizer (observable
//! arrays, asynchronous iterators, promise reactions), and everything once
//! the 32-bit clock has stopped. And no exit under a binding runs anything:
//! script a conversion ran - an init dictionary's getter, a toString - has
//! that binding on the stack below it, which may have begun after the
//! object was made.
//!
//! A constructor that itself runs script: its arguments are converted, and
//! any callback it invokes returns, before the stamp is read - when the
//! trampoline binds the receiver - so a callback that began while it ran
//! has ended, and the stamp is at or past the beginning of every callback
//! still on the stack. A subclass's constructor is script around its
//! super() call, which is the trampoline; `this` is in use until it returns.
//! HTML element constructors make nodes.
//!
//! Re-entrancy (v8_wrapper.cpp `runQueuedFinalizersInTask`,
//! `v8_Isolate_RunFreshFinalizers`):
//! - at a non-zero DOM-algorithm depth only what is fresh, and only at a
//!   return into the innermost callback's own script; everything else runs
//!   only from DeferredTeardown.runOwed, which only the outermost binding
//!   exit reaches. A callback's return into its native caller runs nothing;
//! - never beneath a finalizer: one that runs script, whose binding returns
//!   into it at depth zero, finds the drain on the stack and runs nothing;
//!   that drain takes what was queued meanwhile when the finalizer returns
//!   (cppgc: "Bail out for recursive sweeping calls. This can happen when
//!   finalizers allocate new memory.", sweeper.cc:1197-1211);
//! - never while the returning binding's exception is pending: the bit stays
//!   owed, and the next exit that returns normally runs them.

const runtime = @import("runtime");
const ffi = @import("ffi.zig");
const wrapper_cache = @import("wrapper_cache.zig");

const DeferredTeardown = runtime.gc.DeferredTeardown;

/// createAgent, on the agent's thread: `queue` - the agent's, the host's or
/// its own - is told when a collection of `isolate` queues finalizers, and
/// runs them at its next binding exit into script. Null (an agent with no
/// queue): its finalizers run at the pump and at forced collections only.
pub fn install(isolate: *ffi.Isolate, queue: ?*DeferredTeardown) void {
    const q = queue orelse return;
    q.finalizer_steps = .{ .run = step, .run_fresh = freshStep, .data = isolate };
    ffi.v8_Isolate_SetFinalizersOwed(isolate, q.owedWord(), DeferredTeardown.Owed.finalizers_mask, DeferredTeardown.Owed.fresh_mask);
}

/// The agent's end, its isolate entered, before `queue` can go (a host's is
/// BORROWED until here; the agent's own is freed after its last
/// collections): no collection stores into it from here on, and it owes no
/// finalizers - the agent's last forced collections run what is left.
pub fn uninstall(isolate: *ffi.Isolate, queue: ?*DeferredTeardown) void {
    ffi.v8_Isolate_SetFinalizersOwed(isolate, null, 0, 0);
    const q = queue orelse return;
    q.finalizer_steps = null;
    q.owed.finalizers = false;
    q.owed.fresh = false;
}

/// The queue's finalizer steps: a binding returned into script at depth zero
/// and finalizers are owed.
fn step(data: ?*anyopaque) bool {
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(data orelse return true));
    return ffi.v8_Isolate_RunQueuedFinalizers(isolate);
}

/// The queue's fresh steps: a binding returned into the script of the
/// innermost callback invocation, which began at `innermost` on the agent's
/// callback clock; the outermost on the stack began at `outermost`.
fn freshStep(data: ?*anyopaque, innermost: u32, outermost: u32) DeferredTeardown.FinalizerSteps.Fresh {
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(data orelse return .{ .done = true, .waiting = 0 }));
    var waiting: u32 = 0;
    const done = ffi.v8_Isolate_RunFreshFinalizers(isolate, innermost, outermost, freshStampOf, &waiting);
    return .{ .done = done, .waiting = waiting };
}

/// What `v8_Isolate_RunFreshFinalizers` asks of each finalizer it looks at:
/// only a wrapper cache entry carries a stamp.
fn freshStampOf(finalize: ffi.WeakCallbackFn, data: ?*anyopaque) callconv(.c) u32 {
    return wrapper_cache.freshStampOf(finalize, data);
}
