//! WebIDL dictionary: GPUTexelCopyBufferInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUTexelCopyBufferLayout = @import("GPUTexelCopyBufferLayout.zig").GPUTexelCopyBufferLayout;

pub const GPUTexelCopyBufferInfo = struct {
    // Inherited from GPUTexelCopyBufferLayout
    base: GPUTexelCopyBufferLayout,

    buffer: *runtime.Instance,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "buffer", "GPUBuffer" },
    };
};
