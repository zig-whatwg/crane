//! WebIDL dictionary: GPURenderPipelineDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUVertexState = @import("GPUVertexState.zig").GPUVertexState;
const GPUMultisampleState = @import("GPUMultisampleState.zig").GPUMultisampleState;
const GPUPrimitiveState = @import("GPUPrimitiveState.zig").GPUPrimitiveState;
const GPUFragmentState = @import("GPUFragmentState.zig").GPUFragmentState;
const GPUDepthStencilState = @import("GPUDepthStencilState.zig").GPUDepthStencilState;
const GPUPipelineDescriptorBase = @import("GPUPipelineDescriptorBase.zig").GPUPipelineDescriptorBase;

pub const GPURenderPipelineDescriptor = struct {
    // Inherited from GPUPipelineDescriptorBase
    base: GPUPipelineDescriptorBase,

    vertex: GPUVertexState,
    primitive: ?GPUPrimitiveState = null,
    depthStencil: ?GPUDepthStencilState = null,
    multisample: ?GPUMultisampleState = null,
    fragment: ?GPUFragmentState = null,
};
