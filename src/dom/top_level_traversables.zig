//! The host page's top-level traversable: the navigable record that keeps a
//! Browser page's top-level browsing context, its session history and its
//! WindowProxy across every Window the page's navigations make (HTML 7.3.1.2
//! "top-level traversables"; 7.5.1 "create and initialize a Document object"
//! step 7 gives each replacing document a new Window).
//!
//! The navigation machinery a navigable runs on - an iframe's content
//! navigable, window.open's popup - is HTMLIFrameElement's: a popup is that
//! navigable without a container, and the host page is a popup nothing
//! opened. So HTMLIFrameElement installs this hook and the host (the
//! browser layer's Context) asks it, as Window asks `auxiliary_navigables`
//! for a popup. The host keeps making its own realms (they are parentless
//! and entered for their life, unlike a frame's): the record asks it
//! through `Host`.
//!
//! Spec: https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversables
//!
//! lint-impls: hook for HTMLIFrameElement
const std = @import("std");
const process_start = @import("process_start.zig");

const runtime = @import("runtime");
const Origin = @import("html_core").Origin;

/// What the host supplies to the record it owns.
pub const Host = struct {
    /// The host's own state, handed back to each callback. BORROWED: the host
    /// outlives the record.
    context: *anyopaque,
    /// HTML "create and initialize a Document object" steps 6-7 for a
    /// document of `origin` about to become the traversable's active document:
    /// keep the active window (step 6), or make the realm of a new Window
    /// whose global this is the traversable's WindowProxy (step 7). False when
    /// no realm could be made. Null: the active window is always kept.
    realm_for_document: ?*const fn (context: *anyopaque, origin: Origin) bool = null,
};

/// What HTMLIFrameElement supplies.
pub const Implementation = struct {
    /// The host page's top-level traversable around `window` - its realm's
    /// Window, showing the initial about:blank document - which hands it its
    /// top-level browsing context. The record is the caller's: `destroy`.
    create: *const fn (allocator: std.mem.Allocator, window: *runtime.Instance, host: Host) ?*anyopaque,
    /// The record's end, once every Window it showed is gone (its realms
    /// ended): its navigations end and its browsing context is freed.
    destroy: *const fn (record: *anyopaque) void,
};

// process-wide: immutable function pointers HTMLIFrameElement installs once at process start (process_start.zig); each record they make is its own Context's, of its own Browser
var implementation: ?Implementation = null;

/// Called by HTMLIFrameElement's installHooks, once, at process start
/// (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// Whether the owner has installed its implementation: from process start on,
/// unless a test cleared it.
pub fn isInstalled() bool {
    return implementation != null;
}

/// See Implementation.create. Null when no owner is installed or the record
/// could not be made: the host then keeps its page without one.
pub fn create(allocator: std.mem.Allocator, window: *runtime.Instance, host: Host) ?*anyopaque {
    const impl = implementation orelse return null;
    return impl.create(allocator, window, host);
}

/// See Implementation.destroy.
pub fn destroy(record: *anyopaque) void {
    const impl = implementation orelse return;
    impl.destroy(record);
}
