//! WebIDL dictionary: HighlightHitResult
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const HighlightHitResult = struct {
    highlight: ?*runtime.Instance = null,
    ranges: ?[]const *runtime.Instance = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "highlight", "Highlight" },
        .{ "ranges", "AbstractRange" },
    };
};
