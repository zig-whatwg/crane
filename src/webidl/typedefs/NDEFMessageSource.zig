//! WebIDL typedef: NDEFMessageSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const NDEFMessageSource = union(enum) {
    variant_0: runtime.DOMString,
    variant_1: *const anyopaque,
    variant_2: *const anyopaque,
};
