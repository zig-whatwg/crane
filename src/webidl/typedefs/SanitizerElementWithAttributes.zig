//! WebIDL typedef: SanitizerElementWithAttributes
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const SanitizerElementWithAttributes = union(enum) {
    domstring: runtime.DOMString,
    sanitizer_element_namespace_with_attributes: dictionaries.SanitizerElementNamespaceWithAttributes,
};
