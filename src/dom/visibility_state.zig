//! HTML 6.2 "Page visibility": "update the visibility state" of a Document.
//!
//! A document's visibility state is the Document's own state, and no IDL
//! member sets it: the user agent does, when a top-level traversable's
//! system visibility state changes (a window is minimized or restored). So
//! Document installs this hook from its installHooks, and whoever changes a system
//! visibility state - the WebDriver remote end's "minimize window" today -
//! reaches it without importing Document.
//!
//! Spec: https://html.spec.whatwg.org/multipage/interaction.html#update-the-visibility-state
//!
//! lint-impls: hook for Document

const std = @import("std");
const process_start = @import("process_start.zig");
const runtime = @import("runtime");

/// A visibility state.
pub const State = enum { visible, hidden };

/// What Document supplies.
pub const Implementation = struct {
    /// "Update the visibility state" of `document` to `state`: nothing when
    /// it is already that, else set it and fire visibilitychange.
    update: *const fn (document: *runtime.Instance, state: State) void,
};

/// Process-wide, written once at start-up (process_start.zig).
var implementation: ?Implementation = null;

/// Called by Document's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// "Update the visibility state" of `document` to `state`. With no Document
/// made yet there is no document to update.
pub fn update(document: *runtime.Instance, state: State) void {
    const impl = implementation orelse return;
    impl.update(document, state);
}

test "without an installed implementation updating does nothing" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation nothing reads the document.
    var document: runtime.Instance = undefined;
    update(&document, .hidden);
}

test "update forwards to the installed implementation" {
    const saved = implementation;
    defer implementation = saved;
    const Fake = struct {
        var last: ?State = null;
        fn update(_: *runtime.Instance, state: State) void {
            last = state;
        }
    };
    install(.{ .update = &Fake.update });
    var document: runtime.Instance = undefined;
    update(&document, .hidden);
    try std.testing.expectEqual(@as(?State, .hidden), Fake.last);
}
