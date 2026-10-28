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

pub const Implementation = struct {
    /// Queue a traversal of `window`'s traversable to `step`.
    traverse_to_step: *const fn (window: *runtime.Instance, step: u32) void,
    /// Reload `window`'s navigable ("reload"), if the engine can.
    reload: *const fn (window: *runtime.Instance) void,
    /// The navigation API's reload with an explicit serialized state.
    /// `state` is borrowed for this synchronous call.
    reload_with_navigation_api_state: ?*const fn (window: *runtime.Instance, state: joint_history.SerializedState) void = null,
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

var implementation: ?Implementation = null;

/// Called by History's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// Whether the owner has installed its implementation: from process start on,
/// unless a test cleared it.
pub fn isInstalled() bool {
    return implementation != null;
}

/// Queue a traversal of `window`'s traversable to its session history step
/// `step`.
pub fn traverseToStep(window: *runtime.Instance, step: u32) void {
    const impl = implementation orelse return;
    impl.traverse_to_step(window, step);
}

/// Reload `window`'s navigable.
pub fn reload(window: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.reload(window);
}

/// Reload with the navigation API state supplied by navigation.reload().
/// The reload implementation clones the borrowed state before running script.
pub fn reloadWithNavigationApiState(window: *runtime.Instance, state: joint_history.SerializedState) void {
    const impl = implementation orelse return;
    if (impl.reload_with_navigation_api_state) |reload_with_state| {
        reload_with_state(window, state);
    } else {
        impl.reload(window);
    }
}

/// The URL and history update steps for `window`'s associated Document.
pub fn urlAndHistoryUpdate(window: *runtime.Instance, url: []const u8, serialized: ?joint_history.SerializedState, handling: joint_history.HistoryHandling) void {
    const impl = implementation orelse return;
    impl.url_and_history_update(window, url, serialized, handling);
}

/// Resume a traversal of `window`'s traversable to `step` whose navigate
/// event has been fired.
pub fn resumeTraversal(window: *runtime.Instance, step: u32) void {
    const impl = implementation orelse return;
    impl.resume_traversal(window, step);
}

/// Queue `task` on `navigable`'s active window's loop (Implementation
/// .queue_task). False with no implementation or no loop.
pub fn queueTask(navigables: *Navigables, navigable: *BrowsingContext, task: Task) bool {
    const impl = implementation orelse return false;
    return impl.queue_task(navigables, navigable, task);
}

/// Beforeunload at the active documents of `contexts`: whether one was
/// canceled. Nothing is canceled with no implementation.
pub fn beforeUnloadCanceled(contexts: []const *BrowsingContext, allocator: std.mem.Allocator) bool {
    const impl = implementation orelse return false;
    return impl.before_unload_canceled(contexts, allocator);
}

/// "Update document for history step application" for a same-document
/// entry of `navigable`.
pub fn updateSameDocument(navigable: *BrowsingContext, old_url: []const u8, entry: *joint_history.Entry) void {
    const impl = implementation orelse return;
    impl.update_same_document(navigable, old_url, entry);
}

/// The document info ensureHistoryEntries records; with no implementation,
/// none (error.NotInstalled).
pub fn documentInfo(document: *anyopaque, allocator: std.mem.Allocator) anyerror!joint_history.DocumentInfo {
    const impl = implementation orelse return error.NotInstalled;
    return impl.document_info(document, allocator);
}

test "without an installed implementation nothing traverses" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    var window: runtime.Instance = undefined;
    traverseToStep(&window, 1);
    reload(&window);
}
