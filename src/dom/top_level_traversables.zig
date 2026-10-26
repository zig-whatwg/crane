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
    /// A navigation of the traversable committed `document` (an
    /// `*runtime.Instance`), now its active document - the host keeps what
    /// names the page's document in step with it.
    committed: ?*const fn (context: *anyopaque, document: *anyopaque) void = null,
};

/// What HTMLIFrameElement supplies.
pub const Implementation = struct {
    /// The host page's top-level traversable around `window` - its realm's
    /// Window, showing the initial about:blank document - and the top-level
    /// browsing context it shows (an `html_core.BrowsingContext`), which the
    /// record owns from here on. The record is the caller's: `destroy`.
    create: *const fn (allocator: std.mem.Allocator, window: *runtime.Instance, browsing_context: *anyopaque, host: Host) ?*anyopaque,
    /// The record's end, once every Window it showed is gone (its realms
    /// ended): its navigations end and its browsing context is freed.
    destroy: *const fn (record: *anyopaque) void,
    /// The host made the realm of the traversable's next Window (HTML
    /// "create and initialize a Document object" step 7): the record's
    /// navigations and documents go in it from here on.
    attach_realm: *const fn (record: *anyopaque, realm: runtime.Context) void,
    /// HTML "unload a document and its descendants" for the traversable's
    /// active document - children first; the unloading document cleanup steps
    /// for each (its window's timers, its blob URLs, ...); its child
    /// navigables destroyed - before a load replaces it. With `fire_events`
    /// false - a document whose load event never ran, which Blink
    /// (Document::DispatchUnloadEvents, kLoadEventNotRun) and WebKit
    /// (FrameLoader::dispatchUnloadEvents, m_didCallImplicitClose) unload
    /// without pagehide or unload - the documents are destroyed silently.
    unload_active_document: *const fn (record: *anyopaque, fire_events: bool) void,
    /// The host committed a document of `origin` (serialized; "null" for an
    /// opaque one) without the record's navigation - an embedder's load: the
    /// origin the next navigation compares with (its unload timing, its
    /// navigable target name, step 6's window reuse).
    set_active_origin: *const fn (record: *anyopaque, origin: []const u8) void,
    /// HTML "navigate" the traversable to `url` (serialized, absolute) as the
    /// user agent's own "browser UI" navigation - the embedder's address
    /// bar: beforeunload, the fetch and the commit run as the navigation's
    /// tasks on the page's event loop.
    navigate: *const fn (record: *anyopaque, url: []const u8) void,
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
/// could not be made: the host then keeps its page, and the browsing
/// context, without one.
pub fn create(allocator: std.mem.Allocator, window: *runtime.Instance, browsing_context: *anyopaque, host: Host) ?*anyopaque {
    const impl = implementation orelse return null;
    return impl.create(allocator, window, browsing_context, host);
}

/// See Implementation.attach_realm.
pub fn attachRealm(record: *anyopaque, realm: runtime.Context) void {
    const impl = implementation orelse return;
    impl.attach_realm(record, realm);
}

/// See Implementation.unload_active_document.
pub fn unloadActiveDocument(record: *anyopaque, fire_events: bool) void {
    const impl = implementation orelse return;
    impl.unload_active_document(record, fire_events);
}

/// See Implementation.set_active_origin.
pub fn setActiveOrigin(record: *anyopaque, origin: []const u8) void {
    const impl = implementation orelse return;
    impl.set_active_origin(record, origin);
}

/// See Implementation.navigate.
pub fn navigate(record: *anyopaque, url: []const u8) void {
    const impl = implementation orelse return;
    impl.navigate(record, url);
}

/// See Implementation.destroy.
pub fn destroy(record: *anyopaque) void {
    const impl = implementation orelse return;
    impl.destroy(record);
}
