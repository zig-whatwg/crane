//! WebIDL dictionary: SpatialNavigationSearchOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const SpatialNavigationSearchOptions = struct {
    candidates: ?[]const *runtime.Instance = null,
    container: ?*runtime.Instance = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "candidates", "container" };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "candidates", "Node" },
        .{ "container", "Node" },
    };
};
