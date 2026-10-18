//! Whether a document is fully active, as the event loop asks it of each
//! task's document - and, when it is not, whether it may be again.
//!
//! HTML 8.1.7.1: "A task is runnable if its document is either null or fully
//! active." A Document d "is said to be fully active when d is the active
//! document of a navigable navigable, and either navigable is a top-level
//! traversable or navigable's container document is fully active". The
//! answer is the Document's state, which no IDL member exposes, so Document
//! installs it here from its installHooks and the event loop asks - the
//! shape of `document_lifecycle.zig`.
//!
//! A task that is not runnable stays in its task queue ("the first runnable
//! task in taskQueue") until its document is fully active again, or until
//! "destroy a document" (step 5) removes it. So the event loop needs three
//! answers, not two: fully active (run it), inactive (keep it, in place) and
//! gone - the document can never be fully active again (drop it). WebKit's
//! EventLoop::run makes the same three-way choice per task group: run,
//! keep while suspended, discard once stopped (WebCore/dom/EventLoop.cpp).
//!
//! A task names its document by pointer and slab generation
//! (runtime.EventLoopTask.document, .document_generation): the task does not
//! keep the document, which may be freed while the task waits - and a freed
//! document is gone.
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#concept-task-runnable
//! Spec: https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active
//!
//! lint-impls: hook for Document
const process_start = @import("process_start.zig");

const runtime = @import("runtime");

/// A document's activity, as the event loop classifies a task's document.
pub const Activity = enum {
    /// Fully active: its tasks run.
    fully_active,
    /// Not fully active, and it may be again (it is alive, undestroyed, and
    /// its navigable is open): its tasks wait in place.
    inactive,
    /// It can never be fully active again - freed, its realm ended,
    /// destroyed, never given a browsing context, or its navigable gone or
    /// closed: its tasks are dropped without running.
    gone,
};

/// What Document supplies.
pub const Implementation = struct {
    /// `document` - a live Document, or a live Window standing for its
    /// associated Document now (a global task's) - classified.
    activity: *const fn (document: *runtime.Instance) Activity,
};

// process-wide: function pointers Document installs once at process start (crane.Process), the same for every instance
var implementation: ?Implementation = null;

/// Called by Document's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// The activity of the document a task names - `document` as queued, with
/// the slab generation it had then. A document freed since, or whose realm
/// has ended, is gone. Without an installed implementation (a context built
/// for tests) every live document is fully active.
pub fn activity(document: *anyopaque, generation: u64) Activity {
    const instance: *runtime.Instance = @ptrCast(@alignCast(document));
    // Freed, its slot moved on: the document is gone.
    if (runtime.SlabAllocator.generationOf(instance) != generation) return .gone;
    // Still the same object, so its context is too: a realm that has ended
    // has no document that can be fully active again.
    if (!instance.ctx.hasEngine()) return .gone;
    const impl = implementation orelse return .fully_active;
    return impl.activity(instance);
}

/// Whether the document a task names is fully active now (`activity`).
pub fn fullyActive(document: *anyopaque, generation: u64) bool {
    return activity(document, generation) == .fully_active;
}
