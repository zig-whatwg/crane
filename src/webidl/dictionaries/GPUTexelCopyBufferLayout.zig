//! WebIDL dictionary: GPUTexelCopyBufferLayout
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const GPUTexelCopyBufferLayout = struct {
    offset: ?typedefs.GPUSize64 = null,
    bytesPerRow: ?typedefs.GPUSize32 = null,
    rowsPerImage: ?typedefs.GPUSize32 = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "offset", .{ .number = 0 } },
    };
};
