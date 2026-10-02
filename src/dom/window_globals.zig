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
