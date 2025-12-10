//! WebIDL typedef: RotationMatrixType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RotationMatrixType = union(enum) {
    float32array: runtime.JSValue,
    float64array: runtime.JSValue,
    dommatrix: *runtime.Instance,
};
