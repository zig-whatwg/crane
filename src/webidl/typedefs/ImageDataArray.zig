//! WebIDL typedef: ImageDataArray
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ImageDataArray = union(enum) {
    uint8clamped_array: *const anyopaque,
    float16array: *const anyopaque,
};
