//! WebIDL typedef: SharedStorageResponse
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const SharedStorageResponse = union(enum) {
    variant_0: runtime.USVString,
    variant_1: *const anyopaque,
};
