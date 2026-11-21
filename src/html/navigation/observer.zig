//! A Browser's navigation observer: the one listener told each navigation
//! milestone of its navigables, at the spec step, on the Browser's window
//! thread (lane life1; the CDP design tmp/plans/cdp-part1-design.md section
//! 3.3, N2-N5, agreed with lanes cdph and cdpt through the integrator,
//! 2026-11-21).
//!
//! A generic host hook, not a CDP one: a host that shows navigation progress,
//! an automation protocol (CDP's Page and Network events: frameStartedLoading,
//! frameNavigated, lifecycleEvent, the Page.navigate reply), a test. There is
//! ONE slot per Browser (`Navigables.observer`): the Browser sets its own
//! dispatcher there and fans out to its listeners. Nobody observing costs one
//! null check per milestone.
//!
//! The observer is told synchronously, inside the step. It must not run
//! script, re-enter navigation or free anything the milestone borrows: it
//! records, or enqueues work for later. Everything a milestone carries is
//! BORROWED for the call.
//!
//! Identities: `navigable_id` is the navigable's browsing context id (a
//! top-level traversable's is its TabId; CDP derives its frame ids from it).
//! `navigation_id` is navigate step 7's navigation ID - CDP's loaderId, and
//! its navigation request's requestId - 0 for a document no navigation made
//! (an initial about:blank). A document is named by identity and slab
//! generation, never dereferenced by the observer: a document the observer
//! saw committed carries its navigation id from then on (N4) - the observer
//! keys its own documents, so a Document carries no field for it.
//!
//! The hold point (N3, CDP's waitForDebuggerOnStart; Chrome's TargetHandler
//! throttle defers a paused target's navigation request at WillStartRequest):
//! when `hold_first_navigation` answers true for a navigable, its navigation parks
//! after beforeunload, before its fetch, until `release` resumes it.
const std = @import("std");
const browsing_context = @import("../window/browsing_context.zig");

const Navigables = browsing_context.Navigables;

/// Who started a navigation (HTML navigate's user involvement "browser UI",
/// or a document - a script, a link, a form, a frame's element).
pub const Initiator = enum { browser_ui, document };

/// What a navigation's response makes, decided when it is ready to commit.
pub const ReadyOutcome = enum {
    /// A document, which becomes the navigable's active document.
    document,
    /// A network error: an error document is committed (HTML "display
    /// inline content"); `error_text` says why.
    network_error,
    /// A 204 or 205: no document, the navigable keeps the one it has.
    no_document,
    /// A response handed to external software (a download): no document.
    download,
};

/// How a same-document navigation moved (HTML "URL and history update
/// steps", "navigate to a fragment", a same-document traversal, the
/// navigation API's intercept).
pub const SameDocumentKind = enum { fragment, push, replace, traverse, intercept };

/// Why a started navigation ended without committing.
pub const AbortReason = enum {
    /// A later navigation of the navigable replaced it.
    superseded,
    /// Stopped (window.stop(), the browser's stop, a traversal's update-only
    /// change) or ended with nothing to commit.
    stopped,
    /// Its beforeunload was canceled.
    canceled_by_beforeunload,
    /// Its navigable went (removed, closed, its Browser ended).
    navigable_gone,
    /// Refused before its request (a policy, a file: URL from web content).
    blocked,
};

/// Who made a top-level traversable.
pub const CreatedBy = enum { host, page };

/// A document, by identity and slab generation: compared, never
/// dereferenced by the observer.
pub const DocumentRef = struct {
    document: *anyopaque,
    generation: u64,
};

/// One milestone of one navigable.
pub const Milestone = struct {
    navigable_id: u64,
    /// Navigate step 7's navigation ID (CDP's loaderId); 0 when no
    /// navigation is involved.
    navigation_id: u64 = 0,
    event: Event,
};

pub const Event = union(enum) {
    /// A cross-document navigation started loading: past its navigate event,
    /// before beforeunload and its fetch (CDP frameStartedLoading, and
    /// frameRequestedNavigation for one a document started). A traversal's
    /// or reload's population is one too.
    started: struct { url: []const u8, initiator: Initiator },
    /// Its response is in and decided, before anything unloads (CDP
    /// Page.navigate's reply: loaderId, errorText, isDownload).
    ready_to_commit: struct { url: []const u8, outcome: ReadyOutcome, status: u16 = 0, mime_type: []const u8 = "", error_text: []const u8 = "" },
    /// The new document is its Window's associated Document and the
    /// navigable's active document, before its parser runs a script (CDP
    /// executionContextsCleared, lifecycleEvent init/commit, frameNavigated).
    /// Also an initial about:blank document, with navigation_id 0.
    committed: struct { url: []const u8, document: DocumentRef, mime_type: []const u8, error_page: bool = false },
    /// A same-document navigation updated the URL (CDP navigatedWithinDocument).
    same_document: struct { url: []const u8, kind: SameDocumentKind },
    /// A started navigation ended without committing (CDP loadingFailed).
    aborted: struct { reason: AbortReason },
    /// A document's DOMContentLoaded fired (HTML "the end" step 6).
    dom_content_loaded: struct { document: DocumentRef },
    /// A document's load fired (HTML "the end" step 9).
    load: struct { document: DocumentRef },
    /// The navigable is done loading: its document's load has run and no
    /// navigation of it is in flight, or a navigation ended with nothing
    /// left loading (CDP frameStoppedLoading).
    stopped_loading,
    /// A navigable was made: a child navigable (parent_id set), or a
    /// top-level traversable (opener_id: its opener's id, null for noopener
    /// or a host-made one; created_by).
    navigable_created: struct { parent_id: ?u64 = null, opener_id: ?u64 = null, created_by: CreatedBy = .page },
    /// A navigable is gone - after its close steps: its documents unloaded
    /// and destroyed. Never sent while the navigable still runs.
    navigable_destroyed,
};

/// The Browser's observer (`Navigables.observer`).
pub const Observer = struct {
    context: *anyopaque,
    notify: *const fn (context: *anyopaque, milestone: *const Milestone) void,
    /// Whether the navigable's navigation must wait before its fetch until
    /// `release` (N3: a target created paused - CDP waitForDebuggerOnStart -
    /// holds its first navigation). Asked for each navigation that reaches
    /// its fetch; the observer answers true while the navigable is paused.
    /// Null never holds.
    hold_first_navigation: ?*const fn (context: *anyopaque, navigable_id: u64) bool = null,
};

/// Tell `navigables`' observer, if it has one.
pub fn notify(navigables: ?*const Navigables, milestone: Milestone) void {
    const list = navigables orelse return;
    const observer = list.observer orelse return;
    observer.notify(observer.context, &milestone);
}

/// Whether `navigables`' observer holds navigable `navigable_id`'s
/// navigation before its fetch.
pub fn holds(navigables: ?*const Navigables, navigable_id: u64) bool {
    const list = navigables orelse return false;
    const observer = list.observer orelse return false;
    const hold = observer.hold_first_navigation orelse return false;
    return hold(observer.context, navigable_id);
}

/// Resume navigable `navigable_id`'s navigations held before their fetch
/// (CDP Runtime.runIfWaitingForDebugger): each goes on from a task of its
/// navigable's event loop. The window thread.
pub fn release(navigables: *Navigables, navigable_id: u64) void {
    @import("dom").navigables.resumeHeldNavigations(navigables, navigable_id);
}

test "with no observer nothing is told and nothing is held" {
    var navigables = Navigables.init(std.testing.allocator);
    defer navigables.deinit();
    notify(&navigables, .{ .navigable_id = 1, .event = .stopped_loading });
    try std.testing.expect(!holds(&navigables, 1));
}

test "the observer hears each milestone, and decides the hold" {
    const Probe = struct {
        seen: u32 = 0,
        last: ?std.meta.Tag(Event) = null,
        fn notify(context: *anyopaque, milestone: *const Milestone) void {
            const self: *@This() = @ptrCast(@alignCast(context));
            self.seen += 1;
            self.last = std.meta.activeTag(milestone.event);
        }
        fn hold(_: *anyopaque, navigable_id: u64) bool {
            return navigable_id == 7;
        }
    };
    var probe: Probe = .{};
    var navigables = Navigables.init(std.testing.allocator);
    defer navigables.deinit();
    navigables.observer = .{ .context = &probe, .notify = Probe.notify, .hold_first_navigation = Probe.hold };
    notify(&navigables, .{ .navigable_id = 7, .navigation_id = 3, .event = .{ .started = .{ .url = "https://a.test/", .initiator = .browser_ui } } });
    notify(&navigables, .{ .navigable_id = 7, .event = .stopped_loading });
    try std.testing.expectEqual(@as(u32, 2), probe.seen);
    try std.testing.expectEqual(std.meta.Tag(Event).stopped_loading, probe.last.?);
    try std.testing.expect(holds(&navigables, 7));
    try std.testing.expect(!holds(&navigables, 8));
}
