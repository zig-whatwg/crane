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
const process_start = @import("process_start.zig");

const runtime = @import("runtime");
const joint_history = @import("html_core").navigation.joint_history;

pub const Implementation = struct {
    /// Queue a traversal of `window`'s traversable to `step`.
    traverse_to_step: *const fn (window: *runtime.Instance, step: u32) void,
    /// Reload `window`'s navigable ("reload"), if the engine can.
    reload: *const fn (window: *runtime.Instance) void,
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

test "without an installed implementation nothing traverses" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    var window: runtime.Instance = undefined;
    traverseToStep(&window, 1);
    reload(&window);
}
