//! WebIDL typedef: GPUColor
//!
//! This file is AUTO-GENERATED. Do not edit manually.
//! NOTE: Dictionary types use *runtime.Instance to avoid circular imports

const runtime = @import("runtime");

pub const GPUColor = union(enum) {
    double_sequence: []const f64,
    gpucolor_dict: *runtime.Instance,
};
