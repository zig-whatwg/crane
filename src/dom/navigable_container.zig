//! HTML "container": the element whose content navigable a window's
//! document is in - an iframe for a frame's window, null for a top-level one.
//!
//! "Completely finish loading" (HTML §7.5) fires the load event at the
//! container, so a document that finishes loading needs its window's
//! container, and Window keeps its browsing context in its own state. No IDL
//! member reaches it - `frameElement` is the container only when it is same
//! origin with the caller - so Window installs this hook and other types ask
//! it. The shape of `abort_algorithms.zig`.
//!
//! lint-impls: hook for Window

const runtime = @import("runtime");

/// What Window supplies.
pub const Implementation = struct {
    of: *const fn (window: *runtime.Instance) ?*runtime.Instance,
};

threadlocal var implementation: ?Implementation = null;

/// Called by Window. Idempotent: every call installs the same function.
pub fn install(impl: Implementation) void {
    implementation = impl;
}

/// The container of `window`'s navigable, or null when it has none.
pub fn of(window: *runtime.Instance) ?*runtime.Instance {
    const impl = implementation orelse return null;
    return impl.of(window);
}

test "without an installed implementation no window has a container" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation nothing reads it.
    var window: runtime.Instance = undefined;
    try @import("std").testing.expectEqual(@as(?*runtime.Instance, null), of(&window));
}
