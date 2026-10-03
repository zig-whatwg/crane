//! lint-impls: hook for CryptoKey
//! WebCrypto §13.3: create a key and borrow its immutable native internal slots.

const runtime = @import("runtime");
const Slots = @import("webcrypto").key.Slots;
const process_start = @import("process_start.zig");

pub const Implementation = struct {
    /// Takes ownership of slots on success only.
    create: *const fn (realm: runtime.Context, slots: Slots) anyerror!*runtime.Instance,
    /// Borrowed until the key dies; null for a different interface/uninitialized key.
    get: *const fn (key: *runtime.Instance) ?*const Slots,
};

// process-wide: hook table written once at process start by CryptoKey.installHooks (B0); comptime in B9
var implementation: ?Implementation = null;

pub fn install(value: Implementation) void {
    process_start.assertInstalling();
    implementation = value;
}

/// Create in the key's relevant realm, transferring native ownership on success.
pub fn create(realm: runtime.Context, slots: Slots) !*runtime.Instance {
    const hooks = implementation orelse return error.NotSupportedError;
    return hooks.create(realm, slots);
}

/// Read slots without invoking any script-visible CryptoKey getter.
pub fn get(key: *runtime.Instance) ?*const Slots {
    const hooks = implementation orelse return null;
    return hooks.get(key);
}
