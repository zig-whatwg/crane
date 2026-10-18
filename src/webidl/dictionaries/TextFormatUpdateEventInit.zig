//! WebIDL dictionary: TextFormatUpdateEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const TextFormatUpdateEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    textFormats: ?[]const *runtime.Instance = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "textFormats", .empty_sequence },
    };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "textFormats", "TextFormat" },
    };
};
