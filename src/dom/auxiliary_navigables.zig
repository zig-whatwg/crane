//! window.open()'s new navigable: HTML "the rules for choosing a navigable"
//! making a new top-level traversable whose active browsing context is an
//! auxiliary one.
//!
//! Its V8 context, Window and initial about:blank document are built by the
//! machinery an iframe's content navigable uses - a popup is that navigable
//! without a container - and HTMLIFrameElement owns it, so HTMLIFrameElement
//! installs this hook and Window asks it. The shape of `navigable_container.zig`.
//!
//! Spec: https://html.spec.whatwg.org/multipage/document-sequences.html#creating-a-new-auxiliary-browsing-context
//!
//! lint-impls: hook for HTMLIFrameElement

const std = @import("std");
const runtime = @import("runtime");

/// A navigable made for window.open().
pub const Created = struct {
    /// Its integration: an `html_core.IFrameIntegration`, created with the
    /// allocator the caller passed and owned by the caller from here on. Its
    /// deinit takes the navigable down; the caller then destroys it.
    integration: *anyopaque,
    /// Its active window, showing the initial about:blank document.
    window: *runtime.Instance,
};

/// What HTMLIFrameElement supplies.
pub const Implementation = struct {
    create: *const fn (allocator: std.mem.Allocator, opener_browsing_context: *anyopaque, opener_origin: []const u8, is_popup: bool) ?Created,
};

threadlocal var implementation: ?Implementation = null;

/// Called by HTMLIFrameElement. Idempotent: every call installs the same
/// function.
pub fn install(impl: Implementation) void {
    implementation = impl;
}

/// Whether HTMLIFrameElement has installed its implementation yet - it does
/// so when the first iframe element is created.
pub fn isInstalled() bool {
    return implementation != null;
}

/// A new auxiliary navigable opened by `opener_browsing_context` (an
/// `html_core.BrowsingContext`), whose initial about:blank document takes
/// `opener_origin`. Null when none can be made.
pub fn create(allocator: std.mem.Allocator, opener_browsing_context: *anyopaque, opener_origin: []const u8, is_popup: bool) ?Created {
    const impl = implementation orelse return null;
    return impl.create(allocator, opener_browsing_context, opener_origin, is_popup);
}

test "without an installed implementation no navigable is made" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    try std.testing.expect(!isInstalled());
    // Never dereferenced: with no implementation nothing reads it.
    var opener: u8 = 0;
    try std.testing.expect(create(std.testing.allocator, &opener, "https://example.com", false) == null);
}
