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

const runtime = @import("runtime");
const Origin = @import("html_core").Origin;
const Hook = @import("hook.zig").Hook;

/// What the host supplies to the record it owns.
pub const Host = struct {
    /// The host's own state, handed back to each callback. BORROWED: the host
    /// outlives the record.
    context: *anyopaque,
    /// HTML "create and initialize a Document object" step 7 for a document
    /// of `origin` about to become the traversable's active document: make
    /// the realm of a new Window whose global this is the traversable's
    /// WindowProxy. Step 6 - keeping the initial about:blank's Window when
    /// its origin is same origin-domain with the new document's - is the
    /// record's, as for every navigable. `url` is the new document's - the
    /// realm's creation URL. False when no realm could be made. Null: the
    /// active window is always kept.
    create_window_realm: ?*const fn (context: *anyopaque, origin: Origin, url: []const u8) bool = null,
    /// HTML "create and initialize a Document object" step 10 made
    /// `document` (an `*runtime.Instance`) its Window's associated Document -
    /// the traversable's active document, before its parser or any of its
    /// script runs: the host's names for the page's document follow it from
    /// here, so what the parser's scripts and the embedder's script loader
    /// see is the document being parsed.
    document_created: ?*const fn (context: *anyopaque, document: *anyopaque) void = null,
    /// A navigation of the traversable committed `document` (an
    /// `*runtime.Instance`), now its active document - the host keeps what
    /// names the page's document in step with it. `error_page`: the
    /// navigation's response was a network error, and `document` its error
    /// page.
    committed: ?*const fn (context: *anyopaque, document: *anyopaque, error_page: bool) void = null,
};

/// What the embedder's "browser UI" navigation carries besides its URL.
pub const NavigateOptions = struct {
    /// HTML navigate's `response` argument: the document's markup, supplied
    /// by the embedder rather than fetched - as WebKit's loadHTMLString
    /// (SubstituteData) and Chromium's LoadDataWithBaseURL give theirs. The
    /// document is made from it at the navigation's URL, and its session
    /// history entry keeps it, so a traversal back re-creates the document
    /// from it. BORROWED for the call.
    markup: ?[]const u8 = null,
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
    /// HTML "navigate" the traversable to `url` (serialized, absolute) as the
    /// user agent's own "browser UI" navigation - the embedder's address
    /// bar, or its load of a page it supplies: beforeunload, the fetch and
    /// the commit run as the navigation's tasks on the page's event loop.
    navigate: *const fn (record: *anyopaque, url: []const u8, options: NavigateOptions) void,
    /// Whether the traversable has a navigation in flight: its ongoing
    /// navigation is set. An embedder waiting for its navigation stops when
    /// it commits or this goes false.
    is_navigating: *const fn (record: *anyopaque) bool,
};

// process-wide: immutable function pointers HTMLIFrameElement installs once at process start (process_start.zig), identical for every Browser and thread; all mutable state is on the records they make, each owned by one Context of one Browser on that Browser's thread
var implementation: Hook(?Implementation) = .init(null);

/// Called by HTMLIFrameElement's installHooks, once, at process start
/// (process_start.zig).
pub fn install(impl: Implementation) void {
    implementation.install(impl);
}

/// Whether the owner has installed its implementation: from process start on,
/// unless a test cleared it.
pub fn isInstalled() bool {
    return implementation.get() != null;
}

/// See Implementation.create. Null when no owner is installed or the record
/// could not be made: the host then keeps its page, and the browsing
/// context, without one.
pub fn create(allocator: std.mem.Allocator, window: *runtime.Instance, browsing_context: *anyopaque, host: Host) ?*anyopaque {
    const impl = implementation.get() orelse return null;
    return impl.create(allocator, window, browsing_context, host);
}

/// See Implementation.attach_realm.
pub fn attachRealm(record: *anyopaque, realm: runtime.Context) void {
    const impl = implementation.get() orelse return;
    impl.attach_realm(record, realm);
}

/// See Implementation.navigate.
pub fn navigate(record: *anyopaque, url: []const u8, options: NavigateOptions) void {
    const impl = implementation.get() orelse return;
    impl.navigate(record, url, options);
}

/// See Implementation.is_navigating. False with no owner installed.
pub fn isNavigating(record: *anyopaque) bool {
    const impl = implementation.get() orelse return false;
    return impl.is_navigating(record);
}

/// See Implementation.destroy.
pub fn destroy(record: *anyopaque) void {
    const impl = implementation.get() orelse return;
    impl.destroy(record);
}
