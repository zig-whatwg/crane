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
    /// `realm`'s window's document is kept in the back/forward cache: each
    /// timer of its map of active timers stops, keeping how long it still
    /// had to wait, and its animation frame callbacks wait without a frame
    /// being scheduled for them.
    suspend_timers: *const fn (realm: runtime.Context) void = &noTimers,
    /// The document is reactivated: each suspended timer waits what it still
    /// had to - HTML "reactivate" step 2 shifts each by the suspension's
    /// length - and its animation frame callbacks may run again.
    resume_timers: *const fn (realm: runtime.Context) void = &noTimers,
    /// Native rendering work exists even without animation callbacks.
    request_rendering: *const fn (document: *runtime.Instance) void = &noRendering,
};

fn noTimers(_: runtime.Context) void {}
fn noRendering(_: *runtime.Instance) void {}

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

/// Request a rendering opportunity for Document-owned native work.
pub fn requestRendering(document: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.request_rendering(document);
}

/// The back/forward cache keeps `realm`'s window's document (see
/// Implementation.suspend_timers). Nothing without an installed
/// implementation.
pub fn suspendTimers(realm: runtime.Context) void {
    const impl = implementation orelse return;
    impl.suspend_timers(realm);
}

/// HTML "reactivate" step 2 for `realm`'s window (see
/// Implementation.resume_timers).
pub fn resumeTimers(realm: runtime.Context) void {
    const impl = implementation orelse return;
    impl.resume_timers(realm);
}

/// HTML "unload a document" step 16: "the result of getting the keys for the
/// map of active timers" of `realm`'s window, OWNED by the caller. None
/// without an installed implementation (no window operations were installed
/// either, so no timer was set).
pub fn activeTimerHandles(realm: runtime.Context, allocator: std.mem.Allocator) error{OutOfMemory}![]runtime.TimerId {
    const impl = implementation orelse return &.{};
    return impl.active_timer_handles(realm, allocator);
}
