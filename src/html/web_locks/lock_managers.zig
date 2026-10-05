//! "Each environment settings object has a LockManager object" (Web Locks
//! 3.1), as the `locks` getter of NavigatorLocks reaches it.
//!
//! NavigatorLocks is a mixin of Navigator and WorkerNavigator; the getter
//! returns "this's relevant settings object's LockManager object", which is
//! LockManager's to make and to find - its environment's side of the Browser's
//! lock managers is registered with it. So LockManager installs this hook from
//! its installHooks, and the getter asks it.
//!
//! Spec: https://w3c.github.io/web-locks/#navigator-mixins
//!
//! lint-impls: hook for LockManager

const std = @import("std");
const runtime = @import("runtime");

/// What LockManager supplies.
pub const Implementation = struct {
    /// The LockManager of the environment whose realm is `realm`, made on
    /// first use.
    of: *const fn (realm: runtime.Context) anyerror!*runtime.Instance,
};

// process-wide: function pointers LockManager installs once at process start (crane.Process), the same for every instance
var implementation: ?Implementation = null;

/// Called by LockManager's installHooks, once, at process start
/// (dom.process_start).
pub fn install(impl: Implementation) void {
    @import("dom").process_start.assertInstalling();
    implementation = impl;
}

/// The LockManager of `realm`'s environment. NotSupported before LockManager
/// installed the hook (a context built for tests without one).
pub fn of(realm: runtime.Context) anyerror!*runtime.Instance {
    const impl = implementation orelse return error.NotSupported;
    return impl.of(realm);
}

test "without an installed implementation there is no LockManager" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation nothing reads it.
    var realm: runtime.ContextData = undefined;
    try std.testing.expectError(error.NotSupported, of(&realm));
}
