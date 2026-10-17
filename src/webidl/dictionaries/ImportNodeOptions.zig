//! WebIDL dictionary: ImportNodeOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ImportNodeOptions = struct {
    customElementRegistry: ?*runtime.Instance = null,
    selfOnly: ?bool = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "customElementRegistry", "CustomElementRegistry" },
    };
};
