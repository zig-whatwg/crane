//! WebIDL typedef: RotationMatrixType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const RotationMatrixType = union(enum) {
    float32array: runtime.JSValue,
    float64array: runtime.JSValue,
    dommatrix: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "float32array", .kind = .{ .typed_array = "Float32Array" } },
        .{ .field = "float64array", .kind = .{ .typed_array = "Float64Array" } },
        .{ .field = "dommatrix", .kind = .{ .interface = "DOMMatrix" } },
    };
};
