//! WebIDL typedef: URLPatternInput
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const URLPatternInput = union(enum) {
    variant_0: runtime.USVString,
    variant_1: *const anyopaque,
};
