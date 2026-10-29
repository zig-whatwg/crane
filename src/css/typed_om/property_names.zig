//! CSS Typed OM §3: property-name strings, distinct from declaration tokens.
const std = @import("std");
const properties = @import("../properties.zig");
const custom = @import("../custom_properties.zig");

pub const Name = union(enum) {
    custom: []const u8,
    ordinary: properties.Property,
};

pub fn lookup(name: []const u8) ?Name {
    // Chrome 156 + Safari 27, integrator Q57 (2026-10-27): bare "--"
    // throws, but spaces after it are valid and serialize escaped.
    if (custom.isName(name)) return .{ .custom = name };
    return .{ .ordinary = properties.lookup(name) orelse return null };
}
