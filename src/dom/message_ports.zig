//! HTML's MessagePort transfer steps and transfer-receiving steps (§ 9.4.3),
//! for code that transfers ports without being MessagePort: a Worker's
//! postMessage, a worker's implicit port. No IDL member runs either, so
//! MessagePort installs them here, the shape of `abort_algorithms.zig`.
//!
//! A port's END is its channel end - the port message queue and the
//! entanglement - opaque at this seam. Shipping a port hands its end over as
//! the data holder; receiving it makes a new MessagePort on it in the
//! receiving realm.
//!
//! lint-impls: hook for MessagePort

const runtime = @import("runtime");

pub const Steps = struct {
    /// Whether `instance` can be transferred: not a MessagePort, a
    /// MessagePort, or a detached one (HTML 2.7.5 steps 2.1 and 5.2).
    transferable_state: *const fn (instance: *runtime.Instance) runtime.TransferableState,
    /// The transfer steps for the MessagePort `instance`: it is shipped and
    /// detached, and its end - which the caller now holds, to hand to
    /// `receive` - is returned.
    ship: *const fn (instance: *runtime.Instance) ?*anyopaque,
    /// The transfer-receiving steps: a new MessagePort of `realm` on `end`,
    /// which it takes.
    receive: *const fn (realm: runtime.Context, end: *anyopaque) anyerror!*runtime.Instance,
};

/// Per thread: a worker's ports live on its own thread's realms.
threadlocal var steps: ?Steps = null;

/// Called by MessagePort. Idempotent.
pub fn install(installed: Steps) void {
    steps = installed;
}

/// Whether `instance` can be transferred. Nothing is a transferable port
/// before MessagePort has installed its steps - no port exists yet.
pub fn transferableState(instance: *runtime.Instance) runtime.TransferableState {
    const installed = steps orelse return .not_transferable;
    return installed.transferable_state(instance);
}

/// Ship the MessagePort `instance`: its end, or null when it is not one.
pub fn ship(instance: *runtime.Instance) ?*anyopaque {
    const installed = steps orelse return null;
    return installed.ship(instance);
}

/// A new MessagePort of `realm` on the shipped `end`.
pub fn receive(realm: runtime.Context, end: *anyopaque) !*runtime.Instance {
    const installed = steps orelse return error.NotSupported;
    return installed.receive(realm, end);
}
