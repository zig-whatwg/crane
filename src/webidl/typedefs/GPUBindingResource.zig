//! WebIDL typedef: GPUBindingResource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");

pub const GPUBindingResource = union(enum) {
    gpusampler: *runtime.Instance,
    gputexture: *runtime.Instance,
    gputexture_view: *runtime.Instance,
    gpubuffer: *runtime.Instance,
    gpubuffer_binding: dictionaries.GPUBufferBinding,
    gpuexternal_texture: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "gpusampler", .kind = .{ .interface = "GPUSampler" } },
        .{ .field = "gputexture", .kind = .{ .interface = "GPUTexture" } },
        .{ .field = "gputexture_view", .kind = .{ .interface = "GPUTextureView" } },
        .{ .field = "gpubuffer", .kind = .{ .interface = "GPUBuffer" } },
        .{ .field = "gpubuffer_binding", .kind = .dictionary },
        .{ .field = "gpuexternal_texture", .kind = .{ .interface = "GPUExternalTexture" } },
    };
};
