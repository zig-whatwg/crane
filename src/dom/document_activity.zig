//! Whether a document is fully active, as the event loop asks it of each
//! task's document.
//!
//! HTML 8.1.7.1: "A task is runnable if its document is either null or fully
//! active." A Document d "is said to be fully active when d is the active
//! document of a navigable navigable, and either navigable is a top-level
//! traversable or navigable's container document is fully active". The
//! answer is the Document's state, which no IDL member exposes, so Document
//! installs it here from its installHooks and the event loop asks - the
//! shape of `document_lifecycle.zig`.
//!
//! A task names its document by pointer and slab generation
//! (runtime.EventLoopTask.document, .document_generation): the task does not
//! keep the document, which may be freed while the task waits - and a freed
//! document is not fully active.
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#concept-task-runnable
//! Spec: https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active
//!
//! lint-impls: hook for Document
const process_start = @import("process_start.zig");

const runtime = @import("runtime");

/// What Document supplies.
pub const Implementation = struct {
    /// Whether `document` - a live Document - is fully active.
    fully_active: *const fn (document: *runtime.Instance) bool,
};

// process-wide: function pointers Document installs once at process start (crane.Process), the same for every instance
var implementation: ?Implementation = null;

/// Called by Document's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// Whether the document a task names - `document` as queued, with the slab
/// generation it had then - is fully active now. A document freed since, or
/// whose realm has ended, is not. Without an installed implementation (a
/// context built for tests) every live document is.
pub fn fullyActive(document: *anyopaque, generation: u64) bool {
    const instance: *runtime.Instance = @ptrCast(@alignCast(document));
    // Freed, its slot moved on: the document is gone.
    if (runtime.SlabAllocator.generationOf(instance) != generation) return false;
    // Still the same object, so its context is too: a realm that has ended
    // has no fully active document.
    if (!instance.ctx.hasEngine()) return false;
    const impl = implementation orelse return true;
    return impl.fully_active(instance);
}
