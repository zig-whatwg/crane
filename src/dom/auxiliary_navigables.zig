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
//! Window, which keeps the popups a page opened, installs the other half:
//! choosing among them, or making a new one, for a hyperlink's or a form's
//! target (`chooseTopLevel`).
//!
//! lint-impls: hook for HTMLIFrameElement, Window

const std = @import("std");
const process_start = @import("process_start.zig");
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
    /// HTML "definitely close" the top-level traversable whose active window
    /// is `window`: false when `window` is not a top-level traversable's.
    definitely_close: *const fn (window: *runtime.Instance) bool,
};

var implementation: ?Implementation = null;

/// Called by HTMLIFrameElement's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// Whether the owner has installed its implementation: from process start on,
/// unless a test cleared it.
pub fn isInstalled() bool {
    return implementation != null;
}

/// The navigable "the rules for choosing a navigable" chose among the
/// top-level traversables: an open popup, or a new one. Both BORROWED - the
/// popup is its opener window's, which owns it.
pub const Chosen = struct {
    /// Its `html_core.IFrameIntegration`.
    integration: *anyopaque,
    /// Its active window.
    window: *runtime.Instance,
};

/// What Window supplies: the steps of "the rules for choosing a navigable"
/// that reach past the page's own frames - "find a navigable by target name"
/// among the popups of the page's browsing context group (step 7), and step
/// 8's new top-level traversable, made the way the window open steps make
/// one (the opener window keeps it). A hyperlink's or a form's target that
/// names no frame ends here, and then navigates what was chosen with
/// everything its navigation carries (a form's POST resource, the
/// hyperlink's referrer policy and source element).
pub const TopLevelChooser = struct {
    choose: *const fn (current_window: *runtime.Instance, target: []const u8, noopener: bool) ?Chosen,
};

/// A hook like `implementation`: one stateless function, installed once at
/// process start by Window's installHooks, the same for every Browser and
/// thread.
// process-wide: a hook installed once at process start; its function keeps no state
var top_level_chooser: ?TopLevelChooser = null;

/// Called by Window's installHooks, once, at process start (process_start.zig).
pub fn installTopLevelChooser(impl: TopLevelChooser) void {
    process_start.assertInstalling();
    top_level_chooser = impl;
}

/// "The rules for choosing a navigable" for `target` - not "_self",
/// "_parent", "_top", nor a frame of the page - from `current_window`'s
/// navigable: an open popup by that name in the page's browsing context
/// group, or a new top-level traversable (named `target` unless "_blank";
/// with no opener and in a group of its own when `noopener`). Null when
/// none can be made.
pub fn chooseTopLevel(current_window: *runtime.Instance, target: []const u8, noopener: bool) ?Chosen {
    const impl = top_level_chooser orelse return null;
    return impl.choose(current_window, target, noopener);
}

/// A new auxiliary navigable opened by `opener_browsing_context` (an
/// `html_core.BrowsingContext`), whose initial about:blank document takes
/// `opener_origin`. Null when none can be made.
pub fn create(allocator: std.mem.Allocator, opener_browsing_context: *anyopaque, opener_origin: []const u8, is_popup: bool) ?Created {
    const impl = implementation orelse return null;
    return impl.create(allocator, opener_browsing_context, opener_origin, is_popup);
}

/// HTML "definitely close" the top-level traversable whose active window is
/// `window`: its documents are asked about unloading and unloaded; one that
/// window.open() or a link's or form's target made is then destroyed and its
/// browsing context closed, while the host's own page is left to the host.
/// False when `window` is not a top-level traversable's or nothing is
/// installed.
pub fn definitelyClose(window: *runtime.Instance) bool {
    const impl = implementation orelse return false;
    return impl.definitely_close(window);
}

test "without an installed implementation no navigable is made or closed" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    try std.testing.expect(!isInstalled());
    // Never dereferenced: with no implementation nothing reads it.
    var opener: u8 = 0;
    try std.testing.expect(create(std.testing.allocator, &opener, "https://example.com", false) == null);
    // Never dereferenced either.
    var window: runtime.Instance = undefined;
    try std.testing.expect(!definitelyClose(&window));
}
