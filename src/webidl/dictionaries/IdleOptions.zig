//! WebIDL dictionary: IdleOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const IdleOptions = struct {
    threshold: ?u64 = null,
    signal: ?*runtime.Instance = null,

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{"threshold"};

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "signal", "AbortSignal" },
    };
};
