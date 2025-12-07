//! WebIDL typedef: SanitizerElement
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("root.zig");

pub const SanitizerElement = union(enum) {
    domstring: runtime.DOMString,
    sanitizer_element_namespace: dictionaries.SanitizerElementNamespace,
};
