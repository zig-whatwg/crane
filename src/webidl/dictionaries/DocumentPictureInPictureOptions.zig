//! WebIDL dictionary: DocumentPictureInPictureOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const DocumentPictureInPictureOptions = struct {
    width: ?u64 = null,
    height: ?u64 = null,
    disallowReturnToOpener: ?bool = null,
    preferInitialWindowPlacement: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "width", .{ .number = 0 } },
        .{ "height", .{ .number = 0 } },
        .{ "disallowReturnToOpener", .{ .boolean = false } },
        .{ "preferInitialWindowPlacement", .{ .boolean = false } },
    };

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{ "width", "height" };
};
