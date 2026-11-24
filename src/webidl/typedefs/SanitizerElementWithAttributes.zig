//! WebIDL typedef: SanitizerElementWithAttributes
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");

pub const SanitizerElementWithAttributes = union(enum) {
    domstring: runtime.DOMString,
    sanitizer_element_namespace_with_attributes: dictionaries.SanitizerElementNamespaceWithAttributes,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "domstring", .kind = .string },
        .{ .field = "sanitizer_element_namespace_with_attributes", .kind = .dictionary },
    };
};
