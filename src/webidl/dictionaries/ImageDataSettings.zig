//! WebIDL dictionary: ImageDataSettings
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const ImageDataSettings = struct {
    colorSpace: ?enums.PredefinedColorSpace = null,
    pixelFormat: ?enums.ImageDataPixelFormat = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "pixelFormat", .{ .string = "rgba-unorm8" } },
    };
};
