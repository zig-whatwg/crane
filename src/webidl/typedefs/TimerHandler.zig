//! WebIDL typedef: TimerHandler
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const callbacks = @import("callbacks");

pub const TimerHandler = union(enum) {
    domstring: runtime.DOMString,
    function: callbacks.Function,
    trusted_script: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "domstring", .kind = .string },
        .{ .field = "function", .kind = .callback_function },
        .{ .field = "trusted_script", .kind = .{ .interface = "TrustedScript" } },
    };
};
