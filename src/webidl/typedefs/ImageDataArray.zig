//! WebIDL typedef: ImageDataArray
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const ImageDataArray = union(enum) {
    uint8clamped_array: runtime.JSValue,
    float16array: runtime.JSValue,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "uint8clamped_array", .kind = .{ .typed_array = "Uint8ClampedArray" } },
        .{ .field = "float16array", .kind = .{ .typed_array = "Float16Array" } },
    };
};
