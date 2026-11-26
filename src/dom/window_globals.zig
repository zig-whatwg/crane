//! A Window, the engine global object it is bound to, and the Location and
//! History it owns: the steps on them that no IDL member names, each
//! installed by its owner.
//!
//! "Create a new realm" makes the global object and hands it to the host
//! (engine.createWindowRealm's create_global_object): the Window keeps it,
//! so that a Window reached from another realm - `iframe.contentWindow`,
//! `frames[i]` - is that global, not a second wrapper. Window keeps it in its
//! own state, which no IDL member reaches, so Window installs its steps here
//! (`install`) and the host that makes a frame's Window binds it here.
//!
//! HTML gives every Window one Location and one History ([SameObject], made
//! with the Window in its relevant realm). Each knows its Window - the
//! Location's relevant global, through which "Location-object navigate"
//! reaches the navigable, and the History's, whose navigable's session
//! history it reads - and the code that makes a navigable's Window wires the
//! Location to that navigable: its URL as the navigable's document commits,
//! and the "navigate" its href setter, assign() and replace() run. None of
//! that is an IDL member either, so Location installs its steps here
//! (`installLocation`) and History its own (`installHistory`); the navigable
//! code (HTMLIFrameElement's) and the engine adapter's wrapper cache, which
//! keeps a Window's Location and History alive with the Window, ask here
//! instead of naming the impls (AGENTS.md, the impls boundary). A History's
//! Window and navigable are construction arguments
//! (`interfaces.History.initWith`); only the question is here. One hook slot
//! holds all three owners' steps (Window's, Location's, History's).
//!
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-location-interface
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-history-interface
//!
//! lint-impls: hook for Window, Location, History
const process_start = @import("process_start.zig");
const Hook = @import("hook.zig").Hook;

const runtime = @import("runtime");
const html_core = @import("html_core");

/// What Window supplies.
pub const Implementation = struct {
    /// Bind `window` to `global` (the engine's handle, BORROWED until the
    /// realm ends).
    bind: *const fn (window: *runtime.Instance, global: *anyopaque) void,
    /// Set the Window's associated document during document initialization.
    set_document: *const fn (window: *runtime.Instance, document: *runtime.Instance) void,
    /// The global `window` is bound to, or null when it has none (not bound
    /// yet, or torn down). The ENGINE ADAPTER's own handle, opaque and
    /// BORROWED for the call: only the adapter that bound it reads it, and
    /// nothing outside it may interpret it.
    bound_global: *const fn (window: *runtime.Instance) ?*anyopaque,
    /// The Window stops owning the top-level browsing context Window.init
    /// made for it and hands it to the caller, who frees it from then on -
    /// the host page's top-level traversable, which outlives every Window it
    /// shows (lane newwin1). An `html_core.BrowsingContext`; null when the
    /// Window owns none.
    release_browsing_context: *const fn (window: *runtime.Instance) ?*anyopaque,
    /// Make `window` show `browsing_context` (an `html_core.BrowsingContext`
    /// another owner keeps), its active window from here on, freeing the one
    /// Window.init made for it.
    adopt_browsing_context: *const fn (window: *runtime.Instance, browsing_context: *anyopaque) void,
    /// Set `window`'s current event (DOM 2.3: "Each Window object has an
    /// associated current event") to `event`, returning the previous one -
    /// DOM's inner invoke, around each listener it calls in that Window's
    /// realm (steps 2.9-2.10, 2.15). Null for undefined; BORROWED: set only
    /// while the dispatch that holds the event runs the listener. A Window
    /// torn down keeps none, and answers null.
    swap_current_event: *const fn (window: *runtime.Instance, event: ?*runtime.Instance) ?*runtime.Instance,
    /// The Location `window` has made (HTML 7.2.1: every Window has one,
    /// which `window.location` makes on first use when the host did not
    /// make it with the Window), or null: none made yet, or torn down. A
    /// read: it never makes one. BORROWED: the Window's, for the call.
    location: *const fn (window: *runtime.Instance) ?*runtime.Instance,
    /// CSSOM View "perform a scroll" of `window`'s viewport to the scroll
    /// position (`x`, `y`): what "scroll to the beginning of the document"
    /// (HTML's scroll to the fragment and process scroll behavior) does
    /// with (0, 0). Instant: Crane lays nothing out, so no scrolling area
    /// bounds the position beyond its origin (as Window's scroll()).
    perform_scroll: ?*const fn (window: *runtime.Instance, x: f64, y: f64) void = null,
    /// WindowLocalStorage.localStorage (HTML 12.2.3).
    local_storage: ?*const fn (window: *runtime.Instance) anyerror!*runtime.Instance = null,
    /// WindowSessionStorage.sessionStorage (HTML 12.2.2).
    session_storage: ?*const fn (window: *runtime.Instance) anyerror!*runtime.Instance = null,
    /// Whether `window` has initialized Window internal state.
    has_internal: ?*const fn (window: *runtime.Instance) bool = null,
};

/// What "Location-object navigate" asks of the navigable's engine.
pub const NavigateRequest = html_core.window.iframe_integration.NavigateRequest;

/// The navigable's "navigate" for a Location: `(context, url, request)`,
/// whether a navigable took it. The engine behind it runs "Location-object
/// navigate" step 3 - a relevant document that is not completely loaded
/// makes the navigation a replace - and step 4, "navigate". `context` is the
/// navigable's (an IFrameIntegration), opaque here.
pub const NavigateCallback = *const fn (context: ?*anyopaque, url: []const u8, request: NavigateRequest) bool;

/// What Location supplies.
pub const LocationSteps = struct {
    /// The Window `location` was made for (its relevant global, or the one
    /// `set_window` named), or null: none, or not a Location.
    window: *const fn (location: *runtime.Instance) ?*runtime.Instance,
    /// Make `window` the Window `location` belongs to.
    set_window: *const fn (location: *runtime.Instance, window: *runtime.Instance) void,
    /// The navigable `location` navigates (`callback` with `context`), or
    /// none with a null callback.
    set_navigable: *const fn (location: *runtime.Instance, callback: ?NavigateCallback, context: ?*anyopaque) void,
    /// `location`'s URL is `url`, a URL string its navigable's document
    /// committed with or moved to (a fragment navigation).
    /// Fails as the URL parser does, or out of memory.
    set_url: *const fn (location: *runtime.Instance, url: []const u8) anyerror!void,
};

/// What History supplies.
pub const HistorySteps = struct {
    /// The Window `history` was made for, or null: none, or not a History.
    window: *const fn (history: *runtime.Instance) ?*runtime.Instance,
};

/// Each owner's steps: `window` Window's (`install`), `location` Location's
/// (`installLocation`), `history` History's (`installHistory`).
const Hooks = struct {
    window: ?Implementation = null,
    location: ?LocationSteps = null,
    history: ?HistorySteps = null,
};
var hooks: Hook(Hooks) = .init(.{});

/// Called by Window's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    hooks.installField("window", impl);
}

/// Called by Location's installHooks, once, at process start (process_start.zig).
pub fn installLocation(location_steps: LocationSteps) void {
    hooks.installField("location", location_steps);
}

/// Called by History's installHooks, once, at process start (process_start.zig).
pub fn installHistory(history_steps: HistorySteps) void {
    hooks.installField("history", history_steps);
}

/// Bind `window` to the global object the engine made for its realm.
pub fn bind(window: *runtime.Instance, global: *anyopaque) void {
    const impl = hooks.read().window orelse return;
    impl.bind(window, global);
}

pub fn setDocument(window: *runtime.Instance, document: *runtime.Instance) void {
    (hooks.read().window orelse return).set_document(window, document);
}

/// The global object `window` is bound to (`bind`), or null: torn down, not
/// bound yet, or no Window installed. The engine adapter's opaque handle,
/// BORROWED for the call; read only by that adapter.
pub fn boundGlobal(window: *runtime.Instance) ?*anyopaque {
    const impl = hooks.read().window orelse return null;
    return impl.bound_global(window);
}

/// `window`'s own top-level browsing context, handed to the caller: see
/// Implementation.release_browsing_context.
pub fn releaseBrowsingContext(window: *runtime.Instance) ?*anyopaque {
    const impl = hooks.read().window orelse return null;
    return impl.release_browsing_context(window);
}

/// Make `window` show `browsing_context`: see
/// Implementation.adopt_browsing_context.
pub fn adoptBrowsingContext(window: *runtime.Instance, browsing_context: *anyopaque) void {
    const impl = hooks.read().window orelse return;
    impl.adopt_browsing_context(window, browsing_context);
}

/// The Location `window` has made, or null (see Implementation.location).
/// With no Window installed there is none.
pub fn location(window: *runtime.Instance) ?*runtime.Instance {
    const impl = hooks.read().window orelse return null;
    return impl.location(window);
}

/// See Implementation.perform_scroll. With no Window installed there is no
/// viewport to scroll.
pub fn performScroll(window: *runtime.Instance, x: f64, y: f64) void {
    const impl = hooks.read().window orelse return;
    const perform = impl.perform_scroll orelse return;
    perform(window, x, y);
}

/// See Implementation.swap_current_event. With no Window installed nothing
/// keeps a current event: null.
pub fn swapCurrentEvent(window: *runtime.Instance, event: ?*runtime.Instance) ?*runtime.Instance {
    const impl = hooks.read().window orelse return null;
    return impl.swap_current_event(window, event);
}

/// The Window `location` belongs to; null for a Location made for none, for
/// an object that is no Location, or with no Location installed.
pub fn locationWindow(location_object: *runtime.Instance) ?*runtime.Instance {
    const location_steps = hooks.read().location orelse return null;
    return location_steps.window(location_object);
}

/// Make `window` the Window `location` belongs to.
pub fn setLocationWindow(location_object: *runtime.Instance, window: *runtime.Instance) void {
    const location_steps = hooks.read().location orelse return;
    location_steps.set_window(location_object, window);
}

/// Make `location` navigate a navigable: its href setter, assign() and
/// replace() call `callback` with `context` (see NavigateCallback).
pub fn setLocationNavigable(location_object: *runtime.Instance, callback: ?NavigateCallback, context: ?*anyopaque) void {
    const location_steps = hooks.read().location orelse return;
    location_steps.set_navigable(location_object, callback, context);
}

/// `location`'s URL is now `url` (its navigable's document's).
pub fn setLocationUrl(location_object: *runtime.Instance, url: []const u8) anyerror!void {
    const location_steps = hooks.read().location orelse return error.InvalidStateError;
    return location_steps.set_url(location_object, url);
}

/// The Window `history` belongs to; null for a History made for none, for
/// an object that is no History, or with no History installed.
pub fn historyWindow(history: *runtime.Instance) ?*runtime.Instance {
    const history_steps = hooks.read().history orelse return null;
    return history_steps.window(history);
}

/// WindowLocalStorage.localStorage for `window`.
pub fn localStorageOf(window: *runtime.Instance) anyerror!*runtime.Instance {
    const impl = hooks.read().window orelse return error.InvalidStateError;
    const step = impl.local_storage orelse return error.InvalidStateError;
    return step(window);
}

/// WindowSessionStorage.sessionStorage for `window`.
pub fn sessionStorageOf(window: *runtime.Instance) anyerror!*runtime.Instance {
    const impl = hooks.read().window orelse return error.InvalidStateError;
    const step = impl.session_storage orelse return error.InvalidStateError;
    return step(window);
}

/// Whether `window` has initialized Window internal state.
pub fn hasInternal(window: *runtime.Instance) bool {
    const impl = hooks.read().window orelse return false;
    const step = impl.has_internal orelse return false;
    return step(window);
}

test "with nothing installed no Window, Location or History answers, and setting one does nothing" {
    const std = @import("std");
    const override = hooks.overrideForTest(.{});
    defer override.restore();
    // Never dereferenced: with nothing installed the calls do not reach it.
    var object: runtime.Instance = undefined;
    try std.testing.expectEqual(@as(?*runtime.Instance, null), location(&object));
    try std.testing.expectEqual(@as(?*anyopaque, null), boundGlobal(&object));
    try std.testing.expectEqual(@as(?*runtime.Instance, null), locationWindow(&object));
    try std.testing.expectEqual(@as(?*runtime.Instance, null), historyWindow(&object));
    setLocationWindow(&object, &object);
    setLocationNavigable(&object, null, null);
    try std.testing.expectError(error.InvalidStateError, setLocationUrl(&object, "about:blank"));
}
