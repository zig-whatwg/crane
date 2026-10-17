//! WebIDL dictionary: WriterWriteOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const WriterWriteOptions = struct {
    context: ?runtime.DOMString = null,
    signal: ?*runtime.Instance = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "signal", "AbortSignal" },
    };
};
