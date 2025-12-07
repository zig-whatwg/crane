//! WebIDL typedef: MLNumber
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const MLNumber = union(enum) {
    bigint: *const anyopaque,
    double: f64,
};
