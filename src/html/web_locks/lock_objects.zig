//! "A new Lock object associated with lock" (Web Locks 4.4, step 14.2), as
//! LockManager makes one.
//!
//! A Lock has no constructor script can call, and the lock it is associated
//! with - its name and mode - is the Lock's own state, which no IDL member
//! sets. So Lock installs this hook from its installHooks, and LockManager,
//! which grants the lock, asks it - the shape of dom/navigation_objects.zig.
//!
//! Spec: https://w3c.github.io/web-locks/#lock
//!
//! lint-impls: hook for Lock

const std = @import("std");
const runtime = @import("runtime");
const Mode = @import("registry.zig").Mode;
const Hook = @import("dom").Hook;

/// What Lock supplies.
pub const Implementation = struct {
    /// A new Lock in `realm`, associated with the lock named `name`
    /// (BORROWED; the Lock copies it) whose mode is `mode`.
    create: *const fn (realm: runtime.Context, name: []const u8, mode: Mode) anyerror!*runtime.Instance,
};

// process-wide: function pointers Lock installs once at process start (crane.Process), the same for every instance
var implementation: Hook(?Implementation) = .init(null);

/// Called by Lock's installHooks, once, at process start (dom.process_start).
pub fn install(impl: Implementation) void {
    implementation.install(impl);
}

/// A new Lock in `realm` for the lock `name`/`mode`. NotSupported before
/// Lock installed the hook (a context built for tests without one).
pub fn create(realm: runtime.Context, name: []const u8, mode: Mode) anyerror!*runtime.Instance {
    const impl = implementation.get() orelse return error.NotSupported;
    return impl.create(realm, name, mode);
}

test "without an installed implementation no Lock can be made" {
    const override = implementation.overrideForTest(null);
    defer override.restore();
    // Never dereferenced: with no implementation nothing reads it.
    var realm: runtime.ContextData = undefined;
    try std.testing.expectError(error.NotSupported, create(&realm, "name", .exclusive));
}
