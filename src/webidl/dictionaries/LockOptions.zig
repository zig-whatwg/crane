//! WebIDL dictionary: LockOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const LockOptions = struct {
    mode: ?enums.LockMode = null,
    ifAvailable: ?bool = null,
    steal: ?bool = null,
    signal: ?*runtime.Instance = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "signal", "AbortSignal" },
    };
};
