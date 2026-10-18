//! WebIDL dictionary: ImageDecoderInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const ImageDecoderInit = struct {
    type: runtime.DOMString,
    data: typedefs.ImageBufferSource,
    colorSpaceConversion: ?enums.ColorSpaceConversion = null,
    desiredWidth: ?u32 = null,
    desiredHeight: ?u32 = null,
    preferAnimation: ?bool = null,
    transfer: ?[]const runtime.JSValue = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "colorSpaceConversion", .{ .string = "default" } },
        .{ "transfer", .empty_sequence },
    };

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{ "desiredWidth", "desiredHeight" };
};
