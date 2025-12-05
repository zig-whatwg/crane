//! WebIDL typedef: GPUBindingResource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const dictionaries = @import("dictionaries");

pub const GPUBindingResource = union(enum) {
    gpusampler: *runtime.Instance,
    gputexture: *runtime.Instance,
    gputexture_view: *runtime.Instance,
    gpubuffer: *runtime.Instance,
    gpubuffer_binding: dictionaries.GPUBufferBinding,
    gpuexternal_texture: *runtime.Instance,
};
