//! WebIDL typedef: GPUColor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const dictionaries = @import("dictionaries");

pub const GPUColor = union(enum) {
    double_sequence: []const f64,
    gpucolor_dict: dictionaries.GPUColorDict,

    /// WebIDL `double` and `float` arms (not `unrestricted`): a value one of
    /// them takes is a TypeError when NaN or infinite (3.2.5, 3.2.7, 3.2.25).
    pub const restricted_arms = .{"double_sequence"};
};
