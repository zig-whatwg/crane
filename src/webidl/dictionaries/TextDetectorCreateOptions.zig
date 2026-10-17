//! WebIDL dictionary: TextDetectorCreateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const TextDetectorCreateOptions = struct {
    signal: ?*runtime.Instance = null,
    languages: ?[]const runtime.DOMString = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "signal", "AbortSignal" },
    };
};
