//! WebIDL typedef: GPUColor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const dictionaries = @import("dictionaries");

pub const GPUColor = union(enum) {
    double_sequence: []const f64,
    gpucolor_dict: dictionaries.GPUColorDict,
};
