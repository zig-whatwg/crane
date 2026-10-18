//! WebIDL dictionary: HandwritingHints
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const HandwritingHints = struct {
    recognitionType: ?runtime.DOMString = null,
    inputType: ?runtime.DOMString = null,
    textContext: ?runtime.DOMString = null,
    alternatives: ?u32 = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "recognitionType", .{ .string = "text" } },
        .{ "inputType", .{ .string = "mouse" } },
        .{ "alternatives", .{ .number = 3 } },
    };
};
