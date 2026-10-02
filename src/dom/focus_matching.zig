//! The :focus, :focus-within and :focus-visible pseudo-classes (HTML 4.16.3
//! "Pseudo-classes", Selectors 4 9.4-9.6): whether an element matches them
//! is a question about the focus state of its top-level traversable, which
//! src/html/focus.zig answers from Document's focused-area state - through
//! the same focus-fixup-applying path as activeElement, never the raw
//! designation. Document installs this hook from its installHooks, pointing at those
//! functions, and the selector matchers ask it.
//!
//! lint-impls: hook for Document

const std = @import("std");
const process_start = @import("process_start.zig");
const runtime = @import("runtime");

/// What Document supplies.
pub const Implementation = struct {
    /// :focus - "an element has the focus".
    matches_focus: *const fn (element: *runtime.Instance) bool,
    /// :focus-within - the element or a shadow-including descendant has the focus.
    matches_focus_within: *const fn (element: *runtime.Instance) bool,
    /// :focus-visible - it has the focus and the user agent would indicate it.
    matches_focus_visible: *const fn (element: *runtime.Instance) bool,
};

/// Process-wide, written once at start-up (process_start.zig).
var implementation: ?Implementation = null;

/// Called by Document's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// Whether `element` matches :focus. With no Document made yet, nothing has
/// the focus.
pub fn matchesFocus(element: *runtime.Instance) bool {
    const impl = implementation orelse return false;
    return impl.matches_focus(element);
}

/// Whether `element` matches :focus-within.
pub fn matchesFocusWithin(element: *runtime.Instance) bool {
    const impl = implementation orelse return false;
    return impl.matches_focus_within(element);
}

/// Whether `element` matches :focus-visible.
pub fn matchesFocusVisible(element: *runtime.Instance) bool {
    const impl = implementation orelse return false;
    return impl.matches_focus_visible(element);
}

test "without an installed implementation nothing matches the focus pseudo-classes" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation nothing reads the element.
    var element: runtime.Instance = undefined;
    try std.testing.expect(!matchesFocus(&element));
    try std.testing.expect(!matchesFocusWithin(&element));
    try std.testing.expect(!matchesFocusVisible(&element));
}
