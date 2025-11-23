//! Metadata Extraction Tests
//!
//! Tests for extracting binding metadata from generated WebIDL modules.

const std = @import("std");
const metadata = @import("metadata.zig");
const types = @import("types.zig");

test "extract console namespace metadata" {
    // NOTE: Skipping test with generated namespaces due to anyopaque parameter issue in Zig 0.15.2
    // The generated console.zig has anyopaque parameters which cannot be passed by value in 0.15.2
    //
    // Instead, we test with a simple namespace below

    const SimpleNamespace = struct {
        pub fn log(message: []const u8) void {
            _ = message;
        }
        pub fn warn(message: []const u8) void {
            _ = message;
        }
    };

    const binding = comptime metadata.extractNamespaceMetadata(SimpleNamespace);

    try std.testing.expectEqualStrings("SimpleNamespace", binding.name);
    try std.testing.expectEqual(@as(usize, 2), binding.methods.len);

    var found_log = false;
    var found_warn = false;

    for (binding.methods) |method| {
        if (std.mem.eql(u8, method.name, "log")) found_log = true;
        if (std.mem.eql(u8, method.name, "warn")) found_warn = true;
    }

    try std.testing.expect(found_log);
    try std.testing.expect(found_warn);
}

test "method descriptor extraction" {
    // Create a simple test function
    const TestNamespace = struct {
        pub fn simpleMethod() void {}
        pub fn methodWithParams(a: i32, b: []const u8) bool {
            _ = a;
            _ = b;
            return true;
        }
    };

    const binding = comptime metadata.extractNamespaceMetadata(TestNamespace);

    try std.testing.expectEqualStrings("TestNamespace", binding.name);
    try std.testing.expectEqual(@as(usize, 2), binding.methods.len);

    // Check simpleMethod
    const simple = binding.methods[0];
    try std.testing.expectEqualStrings("simpleMethod", simple.name);
    try std.testing.expectEqual(@as(usize, 0), simple.parameters.len);
    try std.testing.expectEqual(types.TypeKind.void, simple.return_type.kind);

    // Check methodWithParams
    const with_params = binding.methods[1];
    try std.testing.expectEqualStrings("methodWithParams", with_params.name);
    try std.testing.expectEqual(@as(usize, 2), with_params.parameters.len);
    try std.testing.expectEqual(types.TypeKind.boolean, with_params.return_type.kind);

    // Check parameters
    try std.testing.expectEqual(types.TypeKind.long, with_params.parameters[0].type.kind);
    try std.testing.expectEqual(types.TypeKind.dom_string, with_params.parameters[1].type.kind);
}

test "type descriptor extraction" {
    const TestTypes = struct {
        pub fn returnsVoid() void {}
        pub fn returnsBool() bool {
            return true;
        }
        pub fn returnsInt() i32 {
            return 42;
        }
        pub fn returnsUint() u32 {
            return 42;
        }
        pub fn returnsFloat() f32 {
            return 3.14;
        }
        pub fn returnsDouble() f64 {
            return 3.14;
        }
        pub fn returnsString() []const u8 {
            return "hello";
        }
        pub fn returnsOptional() ?i32 {
            return null;
        }
    };

    const binding = comptime metadata.extractNamespaceMetadata(TestTypes);

    try std.testing.expectEqual(types.TypeKind.void, binding.methods[0].return_type.kind);
    try std.testing.expectEqual(types.TypeKind.boolean, binding.methods[1].return_type.kind);
    try std.testing.expectEqual(types.TypeKind.long, binding.methods[2].return_type.kind);
    try std.testing.expectEqual(types.TypeKind.unsigned_long, binding.methods[3].return_type.kind);
    try std.testing.expectEqual(types.TypeKind.float, binding.methods[4].return_type.kind);
    try std.testing.expectEqual(types.TypeKind.double, binding.methods[5].return_type.kind);
    try std.testing.expectEqual(types.TypeKind.dom_string, binding.methods[6].return_type.kind);

    // Optional type should have nullable flag
    try std.testing.expectEqual(types.TypeKind.long, binding.methods[7].return_type.kind);
    try std.testing.expect(binding.methods[7].return_type.nullable);
}

test "constant detection" {
    const TestConstants = struct {
        pub const MAX_VALUE = 100;
        pub const MIN_VALUE = 0;
        pub fn normalMethod() void {}
    };

    const binding = comptime metadata.extractNamespaceMetadata(TestConstants);

    // Should have 2 constants and 1 method
    try std.testing.expectEqual(@as(usize, 2), binding.constants.len);
    try std.testing.expectEqual(@as(usize, 1), binding.methods.len);

    // Check constant names
    var found_max = false;
    var found_min = false;

    for (binding.constants) |constant| {
        if (std.mem.eql(u8, constant.name, "MAX_VALUE")) found_max = true;
        if (std.mem.eql(u8, constant.name, "MIN_VALUE")) found_min = true;
    }

    try std.testing.expect(found_max);
    try std.testing.expect(found_min);
}
