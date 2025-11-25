//! WebIDL typedef: URLPatternCompatible
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const URLPatternCompatible = union(enum) {
    variant_0: runtime.USVString,
    variant_1: *const anyopaque,
    variant_2: *const anyopaque,
};
