//! WebIDL dictionary: CanvasRenderingContext2DSettings
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const CanvasRenderingContext2DSettings = struct {
    alpha: ?bool = null,
    desynchronized: ?bool = null,
    colorSpace: ?enums.PredefinedColorSpace = null,
    colorType: ?enums.CanvasColorType = null,
    willReadFrequently: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "alpha", .{ .boolean = true } },
        .{ "desynchronized", .{ .boolean = false } },
        .{ "colorSpace", .{ .string = "srgb" } },
        .{ "colorType", .{ .string = "unorm8" } },
        .{ "willReadFrequently", .{ .boolean = false } },
    };
};
