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

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "compilationHints", .empty_sequence },
    };
};
