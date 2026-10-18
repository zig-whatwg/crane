//! WebIDL dictionary: ReadableStreamBYOBReaderReadOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ReadableStreamBYOBReaderReadOptions = struct {
    min: ?u64 = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "min", .{ .number = 1 } },
    };

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{"min"};
};
