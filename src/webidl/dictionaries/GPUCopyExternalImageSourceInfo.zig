//! WebIDL dictionary: GPUCopyExternalImageSourceInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const GPUCopyExternalImageSourceInfo = struct {
    source: typedefs.GPUCopyExternalImageSource,
    origin: ?typedefs.GPUOrigin2D = null,
    flipY: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "origin", .empty_dictionary },
        .{ "flipY", .{ .boolean = false } },
    };
};
