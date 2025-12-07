//! WebIDL dictionary: GPUShaderModuleDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUShaderModuleCompilationHint = @import("GPUShaderModuleCompilationHint.zig").GPUShaderModuleCompilationHint;
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPUShaderModuleDescriptor = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    code: runtime.USVString,
    compilationHints: ?[]const GPUShaderModuleCompilationHint = null,
};
