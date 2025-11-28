//! Demo Registry
//!
//! Demonstrates binding registration for a subset of working WebIDL interfaces.
//!
//! This serves as both documentation and testing for the binding system.

const std = @import("std");
const js_bindings = @import("js_bindings");
const types = js_bindings.types;

// NOTE: Cannot import generated interfaces due to anyopaque parameter issues in Zig 0.15.2
// Instead, we create simple mock interfaces to demonstrate the binding system

const MockElement = struct {
    pub fn init(allocator: std.mem.Allocator) !*MockElement {
        _ = allocator;
        unreachable;
    }

    pub fn deinit(self: *MockElement) void {
        _ = self;
    }

    // Attribute: tagName (readonly)
    pub fn get_tagName(self: *MockElement) []const u8 {
        _ = self;
        return "div";
    }

    // Attribute: id (read-write)
    pub fn get_id(self: *MockElement) []const u8 {
        _ = self;
        return "";
    }

    pub fn set_id(self: *MockElement, value: []const u8) void {
        _ = self;
        _ = value;
    }

    // Method: getAttribute
    pub fn call_getAttribute(self: *MockElement, name: []const u8) ?[]const u8 {
        _ = self;
        _ = name;
        return null;
    }

    // Method: setAttribute
    pub fn call_setAttribute(self: *MockElement, name: []const u8, value: []const u8) void {
        _ = self;
        _ = name;
        _ = value;
    }

    pub const ELEMENT_NODE: u16 = 1;
};

const MockDocument = struct {
    pub fn init(allocator: std.mem.Allocator) !*MockDocument {
        _ = allocator;
        unreachable;
    }

    // Attribute: title (read-write)
    pub fn get_title(self: *MockDocument) []const u8 {
        _ = self;
        return "";
    }

    pub fn set_title(self: *MockDocument, value: []const u8) void {
        _ = self;
        _ = value;
    }

    // Method: createElement
    pub fn call_createElement(self: *MockDocument, tagName: []const u8) !*MockElement {
        _ = self;
        _ = tagName;
        unreachable;
    }

    // Method: getElementById
    pub fn call_getElementById(self: *MockDocument, id: []const u8) ?*MockElement {
        _ = self;
        _ = id;
        return null;
    }
};

/// Demo registry with a few mock interfaces
pub const demo = struct {
    /// Registered interface bindings
    pub const interfaces = .{
        .Element = js_bindings.registerInterface(MockElement),
        .Document = js_bindings.registerInterface(MockDocument),
    };

    /// Registered namespace bindings
    pub const namespaces = .{
        // Note: Cannot register generated namespaces due to anyopaque parameter issues in Zig 0.15.2
        // Instead, we demonstrate with a simple mock namespace
        .TestNamespace = js_bindings.registerNamespace(struct {
            pub fn log(message: []const u8) void {
                std.debug.print("{s}\n", .{message});
            }

            pub fn error_(message: []const u8) void {
                std.debug.print("ERROR: {s}\n", .{message});
            }

            pub const VERSION: []const u8 = "1.0.0";
        }),
    };
};

/// Count total registered bindings
pub fn countBindings() struct { interfaces: usize, namespaces: usize } {
    const interface_info = @typeInfo(@TypeOf(demo.interfaces));
    const namespace_info = @typeInfo(@TypeOf(demo.namespaces));

    const interface_fields = switch (interface_info) {
        .@"struct" => |s| s.fields,
        else => @compileError("Expected struct for interfaces"),
    };

    const namespace_fields = switch (namespace_info) {
        .@"struct" => |s| s.fields,
        else => @compileError("Expected struct for namespaces"),
    };

    return .{
        .interfaces = interface_fields.len,
        .namespaces = namespace_fields.len,
    };
}

test "demo registry has bindings" {
    const counts = countBindings();

    try std.testing.expectEqual(@as(usize, 2), counts.interfaces);
    try std.testing.expectEqual(@as(usize, 1), counts.namespaces);
}

test "MockElement binding metadata" {
    const binding = demo.interfaces.Element;

    try std.testing.expectEqualStrings("MockElement", binding.name);

    // Should have attributes
    try std.testing.expectEqual(@as(usize, 2), binding.attributes.len);

    var found_tagName = false;
    var found_id = false;
    var tagName_readonly = false;
    var id_writable = false;

    for (binding.attributes) |attr| {
        if (std.mem.eql(u8, attr.name, "tagName")) {
            found_tagName = true;
            tagName_readonly = attr.readonly;
        }
        if (std.mem.eql(u8, attr.name, "id")) {
            found_id = true;
            id_writable = !attr.readonly;
        }
    }

    try std.testing.expect(found_tagName);
    try std.testing.expect(tagName_readonly); // readonly attribute
    try std.testing.expect(found_id);
    try std.testing.expect(id_writable); // writable attribute

    // Should have call_getAttribute method
    var found_get = false;
    for (binding.methods) |method| {
        if (std.mem.eql(u8, method.name, "call_getAttribute")) {
            found_get = true;
            break;
        }
    }

    try std.testing.expect(found_get);

    // Should have ELEMENT_NODE constant
    var found_constant = false;
    for (binding.constants) |constant| {
        if (std.mem.eql(u8, constant.name, "ELEMENT_NODE")) {
            found_constant = true;
            break;
        }
    }

    try std.testing.expect(found_constant);
}

test "MockDocument binding metadata" {
    const binding = demo.interfaces.Document;

    try std.testing.expectEqualStrings("MockDocument", binding.name);

    // Should have title attribute (writable)
    try std.testing.expectEqual(@as(usize, 1), binding.attributes.len);

    var found_title = false;
    var title_writable = false;
    for (binding.attributes) |attr| {
        if (std.mem.eql(u8, attr.name, "title")) {
            found_title = true;
            title_writable = !attr.readonly;
        }
    }

    try std.testing.expect(found_title);
    try std.testing.expect(title_writable);

    // Should have methods
    try std.testing.expect(binding.methods.len >= 2);

    var found_create = false;
    var found_get = false;

    for (binding.methods) |method| {
        if (std.mem.eql(u8, method.name, "call_createElement")) found_create = true;
        if (std.mem.eql(u8, method.name, "call_getElementById")) found_get = true;
    }

    try std.testing.expect(found_create);
    try std.testing.expect(found_get);
}

test "TestNamespace binding metadata" {
    const binding = demo.namespaces.TestNamespace;

    // Note: Anonymous structs get mangled names, so we just check it's not empty
    try std.testing.expect(binding.name.len > 0);
    try std.testing.expectEqual(@as(usize, 2), binding.methods.len);
    try std.testing.expectEqual(@as(usize, 1), binding.constants.len);

    // Check for log method
    var found_log = false;
    for (binding.methods) |method| {
        if (std.mem.eql(u8, method.name, "log")) {
            found_log = true;
            break;
        }
    }
    try std.testing.expect(found_log);

    // Check for VERSION constant
    var found_version = false;
    for (binding.constants) |constant| {
        if (std.mem.eql(u8, constant.name, "VERSION")) {
            found_version = true;
            break;
        }
    }
    try std.testing.expect(found_version);
}
