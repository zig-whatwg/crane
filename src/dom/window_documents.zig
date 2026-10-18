//! A frame's window whose document is destroyed while its realm lives on -
//! and a window's map of active timers, which its document's unload reads.
//! HTML "destroy a child navigable" destroys the documents of the frame and
//! of every frame inside it; the realms stay for as long as script holds their
//! windows. The document's "unloading document cleanup steps" clear its
//! window's map of active timers, and its animation frame callbacks go with
//! it - state the browser layer keeps (browser/Context.zig's window
//! operations), which no impl reaches. So the browser layer installs this
//! hook, and HTMLIFrameElement calls it for each destroyed frame's realm.
//!
//! The installer is src/browser/Context.zig, not an impl.
//! lint-impls: hook for Context
const std = @import("std");
const process_start = @import("process_start.zig");

const runtime = @import("runtime");

/// What the browser layer supplies.
pub const Implementation = struct {
    /// `realm`'s window's document was destroyed: its timers and animation
    /// frame callbacks end.
    destroyed: *const fn (realm: runtime.Context) void,
    /// The keys of `realm`'s window's map of active timers - the ids
    /// setTimeout and setInterval returned that are neither cleared nor
    /// done - in `allocator`'s memory, OWNED by the caller.
    active_timer_handles: *const fn (realm: runtime.Context, allocator: std.mem.Allocator) error{OutOfMemory}![]runtime.TimerId,
};

var implementation: ?Implementation = null;

/// Called by the browser layer. Idempotent: every call installs the same
/// function.
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// `realm`'s window's document was destroyed. Nothing to end without an
/// installed implementation (no window operations were installed either).
pub fn destroyed(realm: runtime.Context) void {
    const impl = implementation orelse return;
    impl.destroyed(realm);
}

/// HTML "unload a document" step 16: "the result of getting the keys for the
/// map of active timers" of `realm`'s window, OWNED by the caller. None
/// without an installed implementation (no window operations were installed
/// either, so no timer was set).
pub fn activeTimerHandles(realm: runtime.Context, allocator: std.mem.Allocator) error{OutOfMemory}![]runtime.TimerId {
    const impl = implementation orelse return &.{};
    return impl.active_timer_handles(realm, allocator);
}
