//! A Window and the engine global object it is bound to. "Create a new
//! realm" makes the global object and hands it to the host
//! (engine.createWindowRealm's create_global_object): the Window keeps it,
//! so that a Window reached from another realm - `iframe.contentWindow`,
//! `frames[i]` - is that global, not a second wrapper. Window keeps it in its
//! own state, which no IDL member reaches, so Window installs this hook and
//! the host that makes a frame's Window binds it here.
//!
//! lint-impls: hook for Window
const process_start = @import("process_start.zig");

const runtime = @import("runtime");

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
    /// Set the Window's origin, serialized ("null" for an opaque one) - the
    /// one its storage is keyed by until its document says otherwise.
    set_origin: *const fn (window: *runtime.Instance, origin: []const u8) anyerror!void,
    /// The popups `from` opened (window.open's auxiliary navigables, which a
    /// Window keeps) are `to`'s from here, and the realm their realms are
    /// made under is `to`'s: a navigation gave the opener's navigable the new
    /// Window `to` (lane newwin1, B7).
    move_auxiliary_navigables: *const fn (from: *runtime.Instance, to: *runtime.Instance) void,
};

var implementation: ?Implementation = null;

/// Called by Window's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// Bind `window` to the global object the engine made for its realm.
pub fn bind(window: *runtime.Instance, global: *anyopaque) void {
    const impl = implementation orelse return;
    impl.bind(window, global);
}

pub fn setDocument(window: *runtime.Instance, document: *runtime.Instance) void {
    (implementation orelse return).set_document(window, document);
}

/// The global object `window` is bound to (`bind`), or null: torn down, not
/// bound yet, or no Window installed. The engine adapter's opaque handle,
/// BORROWED for the call; read only by that adapter.
pub fn boundGlobal(window: *runtime.Instance) ?*anyopaque {
    const impl = implementation orelse return null;
    return impl.bound_global(window);
}

/// `window`'s own top-level browsing context, handed to the caller: see
/// Implementation.release_browsing_context.
pub fn releaseBrowsingContext(window: *runtime.Instance) ?*anyopaque {
    const impl = implementation orelse return null;
    return impl.release_browsing_context(window);
}

/// Make `window` show `browsing_context`: see
/// Implementation.adopt_browsing_context.
pub fn adoptBrowsingContext(window: *runtime.Instance, browsing_context: *anyopaque) void {
    const impl = implementation orelse return;
    impl.adopt_browsing_context(window, browsing_context);
}

/// Set `window`'s origin: see Implementation.set_origin.
pub fn setOrigin(window: *runtime.Instance, origin: []const u8) !void {
    const impl = implementation orelse return;
    try impl.set_origin(window, origin);
}

/// See Implementation.move_auxiliary_navigables.
pub fn moveAuxiliaryNavigables(from: *runtime.Instance, to: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.move_auxiliary_navigables(from, to);
}
