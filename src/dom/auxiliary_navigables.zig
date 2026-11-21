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
//! A popup belongs to its Browser, not to the window that opened it (HTML
//! 7.3.1.2: top-level traversables are the user agent's; window.opener names
//! the opener browsing context, a reference that goes when that context
//! goes). So the Browser keeps every popup it has (`Popups`, a supplement of
//! its BrowserScope) and closes them all at its end, before its page
//! (`closeAll`); nothing about the opener's lifetime ends one (lane rep1 b2;
//! Blink: a popup's frame is the main frame of its own Page).
//!
//! Window installs the other half: choosing among the popups, or making a
//! new one, for a hyperlink's or a form's target (`chooseTopLevel`).
//!
//! lint-impls: hook for HTMLIFrameElement, Window

const std = @import("std");
const Hook = @import("hook.zig").Hook;
const runtime = @import("runtime");
const SandboxingFlagSet = @import("sandboxing.zig").SandboxingFlagSet;

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
    create: *const fn (allocator: std.mem.Allocator, opener_browsing_context: *anyopaque, is_popup: bool, popup_sandboxing_flags: SandboxingFlagSet, noopener: bool) ?Created,
    /// HTML "definitely close" the top-level traversable whose active window
    /// is `window`: false when `window` is not a top-level traversable's.
    definitely_close: *const fn (window: *runtime.Instance) bool,
    /// The end of a popup's navigable at its Browser's end - "destroy a
    /// top-level traversable": its documents destroyed, its realm ended, its
    /// integration (a `Created.integration`) deinit'd and destroyed.
    destroy: *const fn (integration: *anyopaque) void,
    /// A Window that held `browsing_context` (an `html_core.BrowsingContext`)
    /// ended, and it still lives: if it is a closed popup's and no Window
    /// holds it any more, the popup's record goes now - `forget` it, then
    /// free it, which releases the context.
    window_ended: *const fn (scope: *runtime.BrowserScope, browsing_context: *anyopaque) void,
};

var implementation: Hook(?Implementation) = .init(null);

/// Called by HTMLIFrameElement's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    implementation.install(impl);
}

/// Whether the owner has installed its implementation: from process start on,
/// unless a test cleared it.
pub fn isInstalled() bool {
    return implementation.get() != null;
}

/// The navigable "the rules for choosing a navigable" chose among the
/// top-level traversables: a related page or frame, or a new popup. The
/// result is BORROWED for synchronous navigation; its owner keeps it alive.
pub const Chosen = struct {
    /// Its `html_core.IFrameIntegration`, or null for a host page identified
    /// by `window`, which uses the existing top-level page navigation.
    integration: ?*anyopaque,
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
// process-wide: only a function pointer (Window's chooser), set once by installHooks at process start; it keeps no state, so one serves every Browser and thread
var top_level_chooser: Hook(?TopLevelChooser) = .init(null);

/// Called by Window's installHooks, once, at process start (process_start.zig).
pub fn installTopLevelChooser(impl: TopLevelChooser) void {
    top_level_chooser.install(impl);
}

/// "The rules for choosing a navigable" for `target` - not "_self",
/// "_parent", "_top", nor a frame of the page - from `current_window`'s
/// navigable: an open popup by that name in the page's browsing context
/// group, or a new top-level traversable (named `target` unless "_blank";
/// with no opener and in a group of its own when `noopener`). Null when
/// none can be made.
pub fn chooseTopLevel(current_window: *runtime.Instance, target: []const u8, noopener: bool) ?Chosen {
    const impl = top_level_chooser.get() orelse return null;
    return impl.choose(current_window, target, noopener);
}

/// A new auxiliary navigable opened by `opener_browsing_context` (an
/// `html_core.BrowsingContext`), whose initial about:blank document takes
/// the origin of the opener's active document - HTML "create a new auxiliary
/// browsing context and document" step 4 makes it with that document as its
/// creator, and "create a new browsing context and document" step 5.1 takes
/// creatorOrigin from the creator document's origin - and whose popup
/// sandboxing flag set is
/// `popup_sandboxing_flags` ("the rules for choosing a navigable" step 8.9,
/// dom.sandboxing.popupSandboxingFlags) - the creation sandboxing flags of
/// that document and of every navigation in it. With `noopener` ("the rules
/// for choosing a navigable" step 8.7: a new top-level traversable "given
/// null" opener) the initial about:blank document has no creator: a new
/// policy container ("create a new browsing context and document" given a
/// null creator), though it keeps the opener's origin, as the browsers do
/// (HTMLIFrameElement.createAuxiliaryNavigable). Null when none can be made.
pub fn create(allocator: std.mem.Allocator, opener_browsing_context: *anyopaque, is_popup: bool, popup_sandboxing_flags: SandboxingFlagSet, noopener: bool) ?Created {
    const impl = implementation.get() orelse return null;
    return impl.create(allocator, opener_browsing_context, is_popup, popup_sandboxing_flags, noopener);
}

/// HTML "definitely close" the top-level traversable whose active window is
/// `window`: its documents are asked about unloading and unloaded; one that
/// window.open() or a link's or form's target made is then destroyed and its
/// browsing context closed, while the host's own page is left to the host.
/// False when `window` is not a top-level traversable's or nothing is
/// installed.
pub fn definitelyClose(window: *runtime.Instance) bool {
    const impl = implementation.get() orelse return false;
    return impl.definitely_close(window);
}

/// The popups of one Browser - the navigables `create` made, each a
/// `Created.integration` - which the Browser owns from their making to its
/// end (`closeAll`). A supplement of the Browser's scope (BrowserScope.of):
/// state with an owner, the Browser.
pub const Popups = struct {
    allocator: std.mem.Allocator,
    integrations: std.ArrayListUnmanaged(*anyopaque) = .empty,

    pub fn init(allocator: std.mem.Allocator) Popups {
        return .{ .allocator = allocator };
    }

    /// The scope's end, after the Browser's: `closeAll` ran, so nothing is
    /// left to end - only the list's storage.
    pub fn deinit(self: *Popups) void {
        std.debug.assert(self.integrations.items.len == 0);
        self.integrations.deinit(self.allocator);
    }
};

/// The Browser of `scope` keeps the popup `integration` (a
/// `Created.integration`) until its end. On failure (out of memory) the
/// caller still owns it.
pub fn keep(scope: *runtime.BrowserScope, integration: *anyopaque) error{OutOfMemory}!void {
    const popups = try scope.of(Popups);
    try popups.integrations.append(popups.allocator, integration);
}

/// The Browser of `scope` ends: each of its popups is destroyed (the
/// implementation's `destroy`), the last made first - a popup and the popups
/// it opened in any order, since no popup's end reaches another's. Called
/// before the Browser's page and its agent end, so no realm is left for the
/// agent's end.
pub fn closeAll(scope: *runtime.BrowserScope) void {
    const popups = scope.existing(Popups) orelse return;
    const impl = implementation.get();
    while (popups.integrations.pop()) |integration| {
        if (impl) |i| i.destroy(integration);
    }
}

/// The popups the Browser of `scope` keeps now, each a
/// `Created.integration`. BORROWED until one is kept or forgotten.
pub fn kept(scope: *runtime.BrowserScope) []const *anyopaque {
    const popups = scope.existing(Popups) orelse return &.{};
    return popups.integrations.items;
}

/// The Browser of `scope` stops keeping `integration`: true when it kept it,
/// and the caller frees it. False when it never did, or `closeAll` already
/// took it (it is being destroyed).
pub fn forget(scope: *runtime.BrowserScope, integration: *anyopaque) bool {
    const popups = scope.existing(Popups) orelse return false;
    for (popups.integrations.items, 0..) |item, i| {
        if (item != integration) continue;
        _ = popups.integrations.swapRemove(i);
        return true;
    }
    return false;
}

/// A Window that held `browsing_context` ended and the context lives on:
/// the implementation frees a closed popup's record whose last Window this
/// was (`Implementation.window_ended`). Window's end calls it.
pub fn windowEnded(scope: *runtime.BrowserScope, browsing_context: *anyopaque) void {
    const impl = implementation.get() orelse return;
    impl.window_ended(scope, browsing_context);
}

/// How many popups the Browser of `scope` keeps: open ones, and closed ones
/// a Window still shows (a closed popup's record goes with its last
/// Window).
pub fn count(scope: *runtime.BrowserScope) usize {
    const popups = scope.existing(Popups) orelse return 0;
    return popups.integrations.items.len;
}

test "without an installed implementation no navigable is made or closed" {
    const override = implementation.overrideForTest(null);
    defer override.restore();
    try std.testing.expect(!isInstalled());
    // Never dereferenced: with no implementation nothing reads it.
    var opener: u8 = 0;
    try std.testing.expect(create(std.testing.allocator, &opener, false, .empty, false) == null);
    // Never dereferenced either.
    var window: runtime.Instance = undefined;
    try std.testing.expect(!definitelyClose(&window));
}
