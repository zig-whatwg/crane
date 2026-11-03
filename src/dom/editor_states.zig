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
//! lint-impls: hook for Document

const std = @import("std");
const Hook = @import("hook.zig").Hook;

/// Free an editor state `allocator` (its document's) made.
pub const Free = *const fn (state: *anyopaque, allocator: std.mem.Allocator) void;

// Written once at process start (process_start.zig) and only read
// afterwards, as every hook module's implementation is.
// process-wide: one step frees every Document's editor state, in every Browser on every thread.
var free_step: Hook(?Free) = .init(null);

/// Called by the editing subsystem's installHooks, once, at process start.
pub fn install(step: Free) void {
    free_step.install(step);
}

/// Free a Document's editor state, as its teardown does. With nothing
/// installed no editor state can have been made.
pub fn free(state: *anyopaque, allocator: std.mem.Allocator) void {
    const step = free_step.get() orelse return;
    step(state, allocator);
}
