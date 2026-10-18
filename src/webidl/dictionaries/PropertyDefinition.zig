//! WebIDL dictionary: PropertyDefinition
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PropertyDefinition = struct {
    name: runtime.DOMString,
    syntax: ?runtime.DOMString = null,
    inherits: ?bool = null,
    initialValue: ?runtime.DOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "syntax", .{ .string = "*" } },
        .{ "inherits", .{ .boolean = true } },
    };
};
