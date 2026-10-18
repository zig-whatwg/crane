//! WebIDL dictionary: GPUSamplerDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPUSamplerDescriptor = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    addressModeU: ?enums.GPUAddressMode = null,
    addressModeV: ?enums.GPUAddressMode = null,
    addressModeW: ?enums.GPUAddressMode = null,
    magFilter: ?enums.GPUFilterMode = null,
    minFilter: ?enums.GPUFilterMode = null,
    mipmapFilter: ?enums.GPUMipmapFilterMode = null,
    lodMinClamp: ?f32 = null,
    lodMaxClamp: ?f32 = null,
    compare: ?enums.GPUCompareFunction = null,
    maxAnisotropy: ?u16 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "lodMinClamp", "lodMaxClamp" };

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "addressModeU", .{ .string = "clamp-to-edge" } },
        .{ "addressModeV", .{ .string = "clamp-to-edge" } },
        .{ "addressModeW", .{ .string = "clamp-to-edge" } },
        .{ "magFilter", .{ .string = "nearest" } },
        .{ "minFilter", .{ .string = "nearest" } },
        .{ "mipmapFilter", .{ .string = "nearest" } },
        .{ "lodMinClamp", .{ .number = 0 } },
        .{ "lodMaxClamp", .{ .number = 32 } },
        .{ "maxAnisotropy", .{ .number = 1 } },
    };

    /// [Clamp] members: converted with that branch of ConvertToInt.
    pub const clamp_members = .{"maxAnisotropy"};
};
