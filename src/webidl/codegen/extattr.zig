//! Extended Attribute Parsing
//!
//! This module provides functions for parsing and handling WebIDL extended attributes.

const std = @import("std");
const types = @import("types.zig");

/// Check if an extended attribute with a given name exists
pub fn hasExtAttr(extAttrs: []const types.ExtendedAttribute, name: []const u8) bool {
    for (extAttrs) |attr| {
        if (std.mem.eql(u8, attr.name, name)) {
            return true;
        }
    }
    return false;
}

/// Get the value of an extended attribute (returns null if not found)
pub fn getExtAttr(extAttrs: []const types.ExtendedAttribute, name: []const u8) ?types.ExtAttrRHS {
    for (extAttrs) |attr| {
        if (std.mem.eql(u8, attr.name, name)) {
            return attr.rhs;
        }
    }
    return null;
}

/// Get the identifier value of an extended attribute (returns null if not found or not an identifier)
pub fn getExtAttrIdentifier(extAttrs: []const types.ExtendedAttribute, name: []const u8) ?[]const u8 {
    const rhs = getExtAttr(extAttrs, name) orelse return null;
    return switch (rhs) {
        .identifier => |id| id,
        else => null,
    };
}

/// Get the identifier list value of an extended attribute
pub fn getExtAttrIdentifierList(extAttrs: []const types.ExtendedAttribute, name: []const u8) ?[]const []const u8 {
    const rhs = getExtAttr(extAttrs, name) orelse return null;
    return switch (rhs) {
        .identifierList => |list| list,
        else => null,
    };
}

/// Check if interface is exposed to a given global
pub fn isExposedTo(extAttrs: []const types.ExtendedAttribute, global: []const u8) bool {
    const exposed = getExtAttr(extAttrs, "Exposed") orelse return true; // Default: exposed everywhere

    return switch (exposed) {
        .identifier => |id| std.mem.eql(u8, id, global),
        .identifierList => |list| {
            for (list) |id| {
                if (std.mem.eql(u8, id, global)) return true;
            }
            return false;
        },
        else => true,
    };
}

/// Check if an attribute/operation has CEReactions
pub fn hasCEReactions(extAttrs: []const types.ExtendedAttribute) bool {
    return hasExtAttr(extAttrs, "CEReactions");
}

/// Check if an attribute has SameObject
pub fn hasSameObject(extAttrs: []const types.ExtendedAttribute) bool {
    return hasExtAttr(extAttrs, "SameObject");
}

/// Check if an attribute is Replaceable
pub fn isReplaceable(extAttrs: []const types.ExtendedAttribute) bool {
    return hasExtAttr(extAttrs, "Replaceable");
}

/// Check if an operation/attribute has NewObject
pub fn hasNewObject(extAttrs: []const types.ExtendedAttribute) bool {
    return hasExtAttr(extAttrs, "NewObject");
}

/// Check if an attribute is PutForwards
pub fn getPutForwards(extAttrs: []const types.ExtendedAttribute) ?[]const u8 {
    return getExtAttrIdentifier(extAttrs, "PutForwards");
}

/// Check if an attribute is LegacyNullToEmptyString
pub fn isLegacyNullToEmptyString(extAttrs: []const types.ExtendedAttribute) bool {
    return hasExtAttr(extAttrs, "LegacyNullToEmptyString");
}

/// Get the Constructor arguments if present
pub fn hasConstructor(extAttrs: []const types.ExtendedAttribute) bool {
    return hasExtAttr(extAttrs, "Constructor");
}

/// Check if interface is a Global interface
pub fn isGlobal(extAttrs: []const types.ExtendedAttribute) bool {
    return hasExtAttr(extAttrs, "Global");
}

/// Check if interface has LegacyWindowAlias
pub fn getLegacyWindowAlias(extAttrs: []const types.ExtendedAttribute) ?[]const u8 {
    return getExtAttrIdentifier(extAttrs, "LegacyWindowAlias");
}

/// Check if operation is Unscopable
pub fn isUnscopable(extAttrs: []const types.ExtendedAttribute) bool {
    return hasExtAttr(extAttrs, "Unscopable");
}

// Unit tests
const testing = std.testing;

test "hasExtAttr finds existing attribute" {
    const attrs = [_]types.ExtendedAttribute{
        .{ .name = "Exposed", .rhs = .{ .identifier = "Window" } },
        .{ .name = "CEReactions", .rhs = null },
    };

    try testing.expect(hasExtAttr(&attrs, "Exposed"));
    try testing.expect(hasExtAttr(&attrs, "CEReactions"));
    try testing.expect(!hasExtAttr(&attrs, "SameObject"));
}

test "getExtAttr returns correct value" {
    const attrs = [_]types.ExtendedAttribute{
        .{ .name = "Exposed", .rhs = .{ .identifier = "Window" } },
    };

    const val = getExtAttr(&attrs, "Exposed");
    try testing.expect(val != null);
    try testing.expect(val.? == .identifier);
    try testing.expectEqualStrings("Window", val.?.identifier);
}

test "getExtAttrIdentifier returns identifier value" {
    const attrs = [_]types.ExtendedAttribute{
        .{ .name = "PutForwards", .rhs = .{ .identifier = "href" } },
    };

    const val = getExtAttrIdentifier(&attrs, "PutForwards");
    try testing.expect(val != null);
    try testing.expectEqualStrings("href", val.?);
}

test "getExtAttrIdentifier returns null for non-identifier" {
    const attrs = [_]types.ExtendedAttribute{
        .{ .name = "Exposed", .rhs = .{ .integer = 10 } },
    };

    const val = getExtAttrIdentifier(&attrs, "Exposed");
    try testing.expect(val == null);
}

test "getExtAttrIdentifierList returns list value" {
    const ids = [_][]const u8{ "Window", "Worker" };
    const attrs = [_]types.ExtendedAttribute{
        .{ .name = "Exposed", .rhs = .{ .identifierList = @constCast(&ids) } },
    };

    const val = getExtAttrIdentifierList(&attrs, "Exposed");
    try testing.expect(val != null);
    try testing.expectEqual(@as(usize, 2), val.?.len);
    try testing.expectEqualStrings("Window", val.?[0]);
    try testing.expectEqualStrings("Worker", val.?[1]);
}

test "isExposedTo checks single identifier" {
    const attrs = [_]types.ExtendedAttribute{
        .{ .name = "Exposed", .rhs = .{ .identifier = "Window" } },
    };

    try testing.expect(isExposedTo(&attrs, "Window"));
    try testing.expect(!isExposedTo(&attrs, "Worker"));
}

test "isExposedTo checks identifier list" {
    const ids = [_][]const u8{ "Window", "Worker" };
    const attrs = [_]types.ExtendedAttribute{
        .{ .name = "Exposed", .rhs = .{ .identifierList = @constCast(&ids) } },
    };

    try testing.expect(isExposedTo(&attrs, "Window"));
    try testing.expect(isExposedTo(&attrs, "Worker"));
    try testing.expect(!isExposedTo(&attrs, "ServiceWorker"));
}

test "isExposedTo defaults to true if no Exposed attribute" {
    const attrs = [_]types.ExtendedAttribute{
        .{ .name = "CEReactions", .rhs = null },
    };

    try testing.expect(isExposedTo(&attrs, "Window"));
    try testing.expect(isExposedTo(&attrs, "Worker"));
}

test "hasCEReactions detects CEReactions" {
    const attrs = [_]types.ExtendedAttribute{
        .{ .name = "CEReactions", .rhs = null },
    };

    try testing.expect(hasCEReactions(&attrs));
}

test "hasSameObject detects SameObject" {
    const attrs = [_]types.ExtendedAttribute{
        .{ .name = "SameObject", .rhs = null },
    };

    try testing.expect(hasSameObject(&attrs));
}

test "isReplaceable detects Replaceable" {
    const attrs = [_]types.ExtendedAttribute{
        .{ .name = "Replaceable", .rhs = null },
    };

    try testing.expect(isReplaceable(&attrs));
}

test "hasNewObject detects NewObject" {
    const attrs = [_]types.ExtendedAttribute{
        .{ .name = "NewObject", .rhs = null },
    };

    try testing.expect(hasNewObject(&attrs));
}

test "getPutForwards returns forwarded attribute" {
    const attrs = [_]types.ExtendedAttribute{
        .{ .name = "PutForwards", .rhs = .{ .identifier = "href" } },
    };

    const val = getPutForwards(&attrs);
    try testing.expect(val != null);
    try testing.expectEqualStrings("href", val.?);
}

test "isLegacyNullToEmptyString detects attribute" {
    const attrs = [_]types.ExtendedAttribute{
        .{ .name = "LegacyNullToEmptyString", .rhs = null },
    };

    try testing.expect(isLegacyNullToEmptyString(&attrs));
}

test "hasConstructor detects Constructor" {
    const attrs = [_]types.ExtendedAttribute{
        .{ .name = "Constructor", .rhs = null },
    };

    try testing.expect(hasConstructor(&attrs));
}

test "isGlobal detects Global" {
    const attrs = [_]types.ExtendedAttribute{
        .{ .name = "Global", .rhs = null },
    };

    try testing.expect(isGlobal(&attrs));
}

test "getLegacyWindowAlias returns alias" {
    const attrs = [_]types.ExtendedAttribute{
        .{ .name = "LegacyWindowAlias", .rhs = .{ .identifier = "webkitURL" } },
    };

    const val = getLegacyWindowAlias(&attrs);
    try testing.expect(val != null);
    try testing.expectEqualStrings("webkitURL", val.?);
}

test "isUnscopable detects Unscopable" {
    const attrs = [_]types.ExtendedAttribute{
        .{ .name = "Unscopable", .rhs = null },
    };

    try testing.expect(isUnscopable(&attrs));
}
