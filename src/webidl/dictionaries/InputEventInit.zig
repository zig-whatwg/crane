//! WebIDL dictionary: InputEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const UIEventInit = @import("UIEventInit.zig").UIEventInit;

pub const InputEventInit = struct {
    // Inherited from UIEventInit
    base: UIEventInit,

    data: ?runtime.DOMString = null,
    isComposing: ?bool = null,
    inputType: ?runtime.DOMString = null,
    dataTransfer: ?*runtime.Instance = null,
    targetRanges: ?[]const *runtime.Instance = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "data", .null },
        .{ "isComposing", .{ .boolean = false } },
        .{ "inputType", .{ .string = "" } },
        .{ "dataTransfer", .null },
        .{ "targetRanges", .empty_sequence },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "data", "dataTransfer" };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "dataTransfer", "DataTransfer" },
        .{ "targetRanges", "StaticRange" },
    };
};
