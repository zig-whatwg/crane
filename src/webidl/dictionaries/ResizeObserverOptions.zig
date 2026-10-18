//! WebIDL dictionary: ResizeObserverOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const ResizeObserverOptions = struct {
    box: ?enums.ResizeObserverBoxOptions = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "box", .{ .string = "content-box" } },
    };
};
