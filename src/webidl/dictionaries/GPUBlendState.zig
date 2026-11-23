//! WebIDL dictionary: GPUBlendState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUBlendComponent = @import("GPUBlendComponent.zig").GPUBlendComponent;

pub const GPUBlendState = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    color: GPUBlendComponent,
    alpha: GPUBlendComponent,
};
