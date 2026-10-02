//! Auto-generated mixin: GPUPipelineBase
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUPipelineBaseImpl = @import("impls").GPUPipelineBase;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GPUBindGroupLayout = @import("interfaces").GPUBindGroupLayout;

pub const impl = @import("impls").GPUPipelineBase;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "GPUPipelineBase")) {
        if (comptime @hasDecl(impls.GPUPipelineBase, "installHooks")) impls.GPUPipelineBase.installHooks();
    }
}

/// Extended attributes: [NewObject]
pub fn call_getBindGroupLayout(instance: *runtime.Instance, index: u32) anyerror!*runtime.Instance {
    // [NewObject] - Caller owns the returned object

    return try GPUPipelineBaseImpl.call_getBindGroupLayout(instance, index);
}
