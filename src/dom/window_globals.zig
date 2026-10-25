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
