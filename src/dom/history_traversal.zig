//! Traversing a traversable's session history to a step (HTML 7.4.6 "apply
//! the traverse history step"), which the navigation API's traverseTo(),
//! back() and forward() and its reload() ask of the traversal that
//! history.go() runs. That traversal - its queue and its per-navigable
//! changes - is History's, so History installs this hook and the navigation
//! API asks it without importing History.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html#apply-the-traverse-history-step
//!
//! lint-impls: hook for History
const std = @import("std");
const process_start = @import("process_start.zig");
const Hook = @import("hook.zig").Hook;

const runtime = @import("runtime");
const html_core = @import("html_core");
const joint_history = html_core.navigation.joint_history;
const BrowsingContext = html_core.window.BrowsingContext;
const Navigables = html_core.window.Navigables;

/// A task for `queueTask`: run once with `context`, or dropped - `drop`
/// called instead - when its loop ends first.
pub const Task = struct {
    callback: *const fn (context: ?*anyopaque) void,
    context: ?*anyopaque,
    drop: *const fn (context: ?*anyopaque) void,
};

/// HTML "perform a navigation API traversal" step 12's own steps, which run
/// in the queued traversal before it applies (12.1-12.3): the navigation
/// API's key of the destination, and how the navigation API hears that the
/// traversal ended there - no entry of the navigable has the key, or it is
/// already the navigable's active entry (a traversal queued before took it
/// there). The traversal owns it: exactly one of `reject` and `drop` is
/// called, once.
pub const ApiTraversal = struct {
    key: [36]u8,
    context: *anyopaque,
    /// Steps 12.2.1 and 12.3.1: queue a global task to reject the finished
    /// promise with an "InvalidStateError" DOMException.
    reject: *const fn (context: *anyopaque) void,
    /// The traversal went on to apply, or never ran: nothing to reject.
    drop: *const fn (context: *anyopaque) void,
};

pub const Implementation = struct {
    /// Queue a traversal of `window`'s traversable to `step` - for the
    /// navigation API, with its key's checks (`api`, taken).
    traverse_to_step: *const fn (window: *runtime.Instance, step: u32, api: ?ApiTraversal) void,
    /// Reload `window`'s navigable ("reload"), if the engine can.
    reload: *const fn (window: *runtime.Instance) void,
    /// The navigation API's reload with an explicit serialized state.
    /// `state` is borrowed for this synchronous call.
    reload_with_navigation_api_state: ?*const fn (window: *runtime.Instance, state: joint_history.SerializedState) void = null,
    /// A declarative refresh's reload of `window`'s navigable: a reload
    /// whose "apply the reload history step" aborts the active document and
    /// its descendants once beforeunload has let it go on, as the navigate
    /// it stands for does (navigate step 24.3). Null: a plain reload.
    reload_for_declarative_refresh: ?*const fn (window: *runtime.Instance) void = null,
    /// HTML "URL and history update steps" given `window`'s associated
    /// Document and `url`, with serializedData `serialized` (null: the
    /// default, null) and historyHandling `handling` - what committing an
    /// intercepted push or replace navigate event runs.
    url_and_history_update: *const fn (window: *runtime.Instance, url: []const u8, serialized: ?joint_history.SerializedState, handling: joint_history.HistoryHandling) void,
    /// HTML "resume applying the traverse history step" to `step`, for
    /// `window`'s traversable, after an intercepted traverse navigate event:
    /// the traversal whose navigate event was fired goes on without firing
    /// it again.
    resume_traversal: *const fn (window: *runtime.Instance, step: u32) void,

    // HTML "apply the history step" (html_core
    // navigation.apply_history_step) runs on the traversable's session
    // history traversal queue, engine-free; these are its steps that need a
    // window, a realm or a document (lane nav2 C2, H-NAV2-HT-APPLY).

    /// "Queue a global task on the navigation and traversal task source" of
    /// `navigable`'s active window - or, with none (its realm being
    /// replaced, or no document), on the loop the traversable's queue is
    /// serviced on (traversal_queue serviceContext); `navigables` is its
    /// Browser's list. False when no loop could take it: `task` is not run
    /// and not dropped.
    queue_task: *const fn (navigables: *Navigables, navigable: *BrowsingContext, task: Task) bool,
    /// "Checking if unloading is canceled" for the active documents of
    /// `contexts`, in order: beforeunload at each - each document held with
    /// its generation, skipped if it went. True when one was canceled.
    before_unload_canceled: *const fn (contexts: []const *BrowsingContext, allocator: std.mem.Allocator) bool,
    /// HTML "abort a document and its descendants" for `navigable`'s active
    /// document, as a navigation that has passed its beforeunload does it
    /// (navigate step 24.3): its fetches end, its live XHRs are left to the
    /// unload. Null: nothing is aborted.
    abort_for_navigation: ?*const fn (navigable: *BrowsingContext, allocator: std.mem.Allocator) void = null,
    /// "Update document for history step application" for `navigable`'s
    /// active document and the entry `entry` of its document: its History
    /// and navigation API views written, its URL, history.state, the
    /// navigation API's entries, popstate - and hashchange as a task when
    /// the fragment differs from `old_url`'s.
    update_same_document: *const fn (navigable: *BrowsingContext, old_url: []const u8, entry: *joint_history.Entry) void,
    /// A document's URL and origin, serialized, owned by `allocator`, for
    /// BrowsingContext.ensureHistoryEntries.
    document_info: *const fn (document: *anyopaque, allocator: std.mem.Allocator) anyerror!joint_history.DocumentInfo,
};

var implementation: Hook(?Implementation) = .init(null);

/// Called by History's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    implementation.install(impl);
}

/// Whether the owner has installed its implementation: from process start on,
/// unless a test cleared it.
pub fn isInstalled() bool {
    return implementation.get() != null;
}

/// Queue a traversal of `window`'s traversable to its session history step
/// `step`.
pub fn traverseToStep(window: *runtime.Instance, step: u32, api: ?ApiTraversal) void {
    const impl = implementation.get() orelse {
        if (api) |a| a.drop(a.context);
        return;
    };
    impl.traverse_to_step(window, step, api);
}

/// Reload `window`'s navigable.
pub fn reload(window: *runtime.Instance) void {
    const impl = implementation.get() orelse return;
    impl.reload(window);
}

/// Reload `window`'s navigable for its document's declarative refresh
/// (Implementation.reload_for_declarative_refresh); a plain reload when the
/// owner has no such step.
pub fn reloadForDeclarativeRefresh(window: *runtime.Instance) void {
    const impl = implementation.get() orelse return;
    if (impl.reload_for_declarative_refresh) |reload_for_refresh| {
        reload_for_refresh(window);
    } else {
        impl.reload(window);
    }
}

/// Reload with the navigation API state supplied by navigation.reload().
/// The reload implementation clones the borrowed state before running script.
pub fn reloadWithNavigationApiState(window: *runtime.Instance, state: joint_history.SerializedState) void {
    const impl = implementation.get() orelse return;
    if (impl.reload_with_navigation_api_state) |reload_with_state| {
        reload_with_state(window, state);
    } else {
        impl.reload(window);
    }
}

/// The URL and history update steps for `window`'s associated Document.
pub fn urlAndHistoryUpdate(window: *runtime.Instance, url: []const u8, serialized: ?joint_history.SerializedState, handling: joint_history.HistoryHandling) void {
    const impl = implementation.get() orelse return;
    impl.url_and_history_update(window, url, serialized, handling);
}

/// Resume a traversal of `window`'s traversable to `step` whose navigate
/// event has been fired.
pub fn resumeTraversal(window: *runtime.Instance, step: u32) void {
    const impl = implementation.get() orelse return;
    impl.resume_traversal(window, step);
}

/// Queue `task` on `navigable`'s active window's loop (Implementation
/// .queue_task). False with no implementation or no loop.
pub fn queueTask(navigables: *Navigables, navigable: *BrowsingContext, task: Task) bool {
    const impl = implementation.get() orelse return false;
    return impl.queue_task(navigables, navigable, task);
}

/// Beforeunload at the active documents of `contexts`: whether one was
/// canceled. Nothing is canceled with no implementation.
pub fn beforeUnloadCanceled(contexts: []const *BrowsingContext, allocator: std.mem.Allocator) bool {
    const impl = implementation.get() orelse return false;
    return impl.before_unload_canceled(contexts, allocator);
}

/// See Implementation.abort_for_navigation.
pub fn abortForNavigation(navigable: *BrowsingContext, allocator: std.mem.Allocator) void {
    const impl = implementation.get() orelse return;
    const abort = impl.abort_for_navigation orelse return;
    abort(navigable, allocator);
}

/// "Update document for history step application" for a same-document
/// entry of `navigable`.
pub fn updateSameDocument(navigable: *BrowsingContext, old_url: []const u8, entry: *joint_history.Entry) void {
    const impl = implementation.get() orelse return;
    impl.update_same_document(navigable, old_url, entry);
}

/// The document info ensureHistoryEntries records; with no implementation,
/// none (error.NotInstalled).
pub fn documentInfo(document: *anyopaque, allocator: std.mem.Allocator) anyerror!joint_history.DocumentInfo {
    const impl = implementation.get() orelse return error.NotInstalled;
    return impl.document_info(document, allocator);
}

test "without an installed implementation nothing traverses" {
    const override = implementation.overrideForTest(null);
    defer override.restore();
    var window: runtime.Instance = undefined;
    traverseToStep(&window, 1, null);
    reload(&window);
    reloadForDeclarativeRefresh(&window);
}
