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

const runtime = @import("runtime");

pub const Implementation = struct {
    /// Queue a traversal of `window`'s traversable to `step`.
    traverse_to_step: *const fn (window: *runtime.Instance, step: u32) void,
    /// Reload `window`'s navigable ("reload"), if the engine can.
    reload: *const fn (window: *runtime.Instance) void,
};

threadlocal var implementation: ?Implementation = null;

/// Called by History. Idempotent.
pub fn install(impl: Implementation) void {
    implementation = impl;
}

/// Whether History has installed the implementation - it does when its first
/// object is made; a caller with none makes one first.
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

test "without an installed implementation nothing traverses" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    var window: runtime.Instance = undefined;
    traverseToStep(&window, 1);
    reload(&window);
}
