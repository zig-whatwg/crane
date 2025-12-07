//! WebIDL dictionary: GPUTexelCopyBufferInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const GPUTexelCopyBufferLayout = @import("GPUTexelCopyBufferLayout.zig").GPUTexelCopyBufferLayout;

pub const GPUTexelCopyBufferInfo = struct {
    // Inherited from GPUTexelCopyBufferLayout
    base: GPUTexelCopyBufferLayout,

    buffer: *runtime.Instance,
};
