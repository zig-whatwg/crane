//! The attribute qualified names every element shares (lane perf3, D1),
//! forwarded: lane nd2 batch 2 (A2) moved the static names, their records
//! and their comptime perfect hash to dom.attribute_names, where an
//! attribute's entry decodes its u32 name id without reaching the html
//! module. See that file for the tables and their sources.
//!
//! Spec: https://html.spec.whatwg.org/multipage/indices.html#attributes-3
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#adjust-foreign-attributes

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");

const attribute_names = dom.attribute_names;
const QualifiedName = attribute_names.QualifiedName;

/// The known attribute local names in no namespace.
pub const names = attribute_names.names;

/// HTML "adjust foreign attributes": the names the parser puts in a
/// namespace, each with its prefix.
pub const foreign = attribute_names.foreign;

/// The static record of exactly this name, or null when no table has it.
pub fn intern(namespace: ?[]const u8, prefix: ?[]const u8, local_name: []const u8) ?*const QualifiedName {
    return attribute_names.staticRecord(attribute_names.staticId(namespace, prefix, local_name) orelse return null);
}

test "the forwarder answers with dom.attribute_names' static records" {
    for (names, 0..) |name, i| try std.testing.expect(intern(null, null, name) == &attribute_names.static_records[i]);
    try std.testing.expect(intern(null, null, "data-x") == null);
    try std.testing.expect(intern(infra.namespaces.XLINK_NAMESPACE, "xlink", "href") != null);
}
