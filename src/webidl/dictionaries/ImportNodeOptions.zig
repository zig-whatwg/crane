//! WebIDL dictionary: ImportNodeOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ImportNodeOptions = struct {
    customElementRegistry: ?*runtime.Instance = null,
    selfOnly: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "selfOnly", .{ .boolean = false } },
    };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "customElementRegistry", "CustomElementRegistry" },
    };
};
