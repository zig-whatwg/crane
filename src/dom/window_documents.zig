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
const Hook = @import("hook.zig").Hook;

const runtime = @import("runtime");

/// What becomes of the Window of a document that is destroyed: it is
/// discarded with it, or the next document of its navigable keeps it (HTML
/// "create and initialize a Document object" step 6: an initial about:blank
/// replaced by a same origin-domain document - "both ... will share the same
/// Window object").
pub const WindowFate = enum { discarded, kept_for_next_document };

/// What the browser layer supplies.
pub const Implementation = struct {
    /// `realm`'s window's document was destroyed: its timers and animation
    /// frame callbacks end, and the unloading document cleanup steps run -
    /// the global teardown ones only when `fate` is `.discarded`
    /// (dom.unloading_cleanup).
    destroyed: *const fn (realm: runtime.Context, fate: WindowFate) void,
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
};

fn noTimers(_: runtime.Context) void {}

var implementation: Hook(?Implementation) = .init(null);

/// Called by the browser layer. Idempotent: every call installs the same
/// function.
pub fn install(impl: Implementation) void {
    implementation.install(impl);
}

/// `realm`'s window's document was destroyed, and the window with it.
/// Nothing to end without an installed implementation (no window operations
/// were installed either).
pub fn destroyed(realm: runtime.Context) void {
    const impl = implementation.get() orelse return;
    impl.destroyed(realm, .discarded);
}

/// `realm`'s window's document was destroyed, and the next document of its
/// navigable keeps the window (`WindowFate.kept_for_next_document`): the
/// document's state ends, the global's does not.
pub fn documentReplaced(realm: runtime.Context) void {
    const impl = implementation.get() orelse return;
    impl.destroyed(realm, .kept_for_next_document);
}

/// Request a rendering opportunity for Document-owned native work: the
/// event loop's frame request (dom.update_the_rendering.requestFrame), which
/// this forwards to for its existing callers.
pub fn requestRendering(document: *runtime.Instance) void {
    @import("update_the_rendering.zig").requestFrame(document);
}

/// The back/forward cache keeps `realm`'s window's document (see
/// Implementation.suspend_timers). Nothing without an installed
/// implementation.
pub fn suspendTimers(realm: runtime.Context) void {
    const impl = implementation.get() orelse return;
    impl.suspend_timers(realm);
}

/// HTML "reactivate" step 2 for `realm`'s window (see
/// Implementation.resume_timers).
pub fn resumeTimers(realm: runtime.Context) void {
    const impl = implementation.get() orelse return;
    impl.resume_timers(realm);
}

/// HTML "unload a document" step 16: "the result of getting the keys for the
/// map of active timers" of `realm`'s window, OWNED by the caller. None
/// without an installed implementation (no window operations were installed
/// either, so no timer was set).
pub fn activeTimerHandles(realm: runtime.Context, allocator: std.mem.Allocator) error{OutOfMemory}![]runtime.TimerId {
    const impl = implementation.get() orelse return &.{};
    return impl.active_timer_handles(realm, allocator);
}
