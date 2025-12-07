//! WebIDL dictionary: MLTensorDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const MLOperandDescriptor = @import("MLOperandDescriptor.zig").MLOperandDescriptor;

pub const MLTensorDescriptor = struct {
    // Inherited from MLOperandDescriptor
    base: MLOperandDescriptor,

    readable: ?bool = null,
    writable: ?bool = null,
};
