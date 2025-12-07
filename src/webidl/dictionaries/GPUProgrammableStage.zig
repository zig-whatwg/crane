//! WebIDL dictionary: GPUProgrammableStage
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const GPUProgrammableStage = struct {
    module: *runtime.Instance,
    entryPoint: ?runtime.USVString = null,
    constants: ?[]const struct { key: runtime.USVString, value: typedefs.GPUPipelineConstantValue } = null,
};
