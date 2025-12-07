//! WebIDL typedef: RotationMatrixType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const RotationMatrixType = union(enum) {
    float32array: *const anyopaque,
    float64array: *const anyopaque,
    dommatrix: *runtime.Instance,
};
