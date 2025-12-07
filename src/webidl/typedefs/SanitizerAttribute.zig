//! WebIDL typedef: SanitizerAttribute
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const SanitizerAttribute = union(enum) {
    domstring: runtime.DOMString,
    sanitizer_attribute_namespace: dictionaries.SanitizerAttributeNamespace,
};
