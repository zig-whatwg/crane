//! The editing subsystem's per-document editor state, as a Document keeps
//! it: one lazily set, opaque pointer in its state
//! (dom.document_internals.editorState / setEditorState), freed by the
//! Document's own teardown through the step the editing subsystem installs
//! here at process start - so Document never names the editing code, and the
//! state lives exactly as long as its document.
//!
//! It used to be a process-global, unlocked map keyed by the document's
//! address, made with the first caller's allocator and never emptied: a
//! leak per document that ran an editing command, a race between Browsers
//! on two threads, and a stale state for a new document at a reused address
//! (lane leaks6).
//!
//! The state holds nodes for script - its undo history's steps keep the
//! nodes they changed (html_core editing/history.zig) - so two more steps
//! reach it: the Document's `traceHeldNodes` names them to the collector
//! (`trace`), and a destroyed Document lets them go (`releaseNodes`, refcount
//! step 7b: a destroyed document's own state lets go of its references on
//! its nodes, as its top layer and autofocus candidates do).
//!
//! lint-impls: hook for Document

const std = @import("std");
const Hook = @import("hook.zig").Hook;

/// The engine's tracer, as a holder's `traceHeldNodes` receives it.
pub const Tracer = @import("engine").Tracer;

/// Free an editor state `allocator` (its document's) made.
pub const Free = *const fn (state: *anyopaque, allocator: std.mem.Allocator) void;

/// Name the nodes an editor state holds to the collector, in its atomic
/// pause: reads only.
pub const Trace = *const fn (state: *anyopaque, tracer: *Tracer) void;

/// Let go of every node an editor state holds; the state itself stays.
pub const ReleaseNodes = *const fn (state: *anyopaque) void;

/// Whether an editor state holds any node now.
pub const HoldsNodes = *const fn (state: *anyopaque) bool;

/// The editing subsystem's steps.
pub const Steps = struct {
    free: Free,
    trace: Trace,
    release_nodes: ReleaseNodes,
    holds_nodes: HoldsNodes,
};

// Written once at process start (process_start.zig) and only read
// afterwards, as every hook module's implementation is.
// process-wide: one set of steps serves every Document's editor state, in every Browser on every thread.
var steps: Hook(?Steps) = .init(null);

/// Called by the editing subsystem's installHooks, once, at process start.
pub fn install(installed: Steps) void {
    steps.install(installed);
}

/// Free a Document's editor state, as its teardown does. With nothing
/// installed no editor state can have been made.
pub fn free(state: *anyopaque, allocator: std.mem.Allocator) void {
    const installed = steps.get() orelse return;
    installed.free(state, allocator);
}

/// The Document's `traceHeldNodes`: the nodes its editor state holds.
pub fn trace(state: *anyopaque, tracer: *Tracer) void {
    const installed = steps.get() orelse return;
    installed.trace(state, tracer);
}

/// A destroyed Document's editor state lets go of the nodes it holds.
pub fn releaseNodes(state: *anyopaque) void {
    const installed = steps.get() orelse return;
    installed.release_nodes(state);
}

/// Whether a Document's editor state holds nodes now - a non-empty undo
/// history - so its destruction has references of its own to end
/// (dom.refcount_teardown's holdsOwnReferences). Most editor states hold
/// none.
pub fn holdsNodes(state: *anyopaque) bool {
    const installed = steps.get() orelse return false;
    return installed.holds_nodes(state);
}
