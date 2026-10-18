//! WebIDL dictionary: GPURenderPassLayout
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPURenderPassLayout = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    colorFormats: []const runtime.JSValue,
    depthStencilFormat: ?enums.GPUTextureFormat = null,
    sampleCount: ?typedefs.GPUSize32 = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "sampleCount", .{ .number = 1 } },
    };
};
