//! WebIDL dictionary: GPURenderBundleEncoderDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPURenderPassLayout = @import("GPURenderPassLayout.zig").GPURenderPassLayout;

pub const GPURenderBundleEncoderDescriptor = struct {
    // Inherited from GPURenderPassLayout
    base: GPURenderPassLayout,

    depthReadOnly: ?bool = null,
    stencilReadOnly: ?bool = null,
};
