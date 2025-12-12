//! Binding Generator Unit Tests
//!
//! Tests for InterfaceBindingGenerator comptime functionality:
//! - Descriptor generation from interface types
//! - Method extraction
//! - Property extraction
//! - Inheritance handling
//! - Mixin handling
//! - Type conversion
//!
//! NOTE ON BaseType = ?*anyopaque:
//! The mock interfaces use `BaseType = ?*anyopaque` because they're testing the
//! current binding generator behavior. This reflects the actual interface metadata
//! pattern. If the source is refactored to use typed BaseType, these mocks should
//! be updated to match. For now, they correctly test the existing code paths.

const std = @import("std");
const testing = std.testing;

const binding_generator = @import("runtime").binding_generator;
const InterfaceBindingGenerator = binding_generator.InterfaceBindingGenerator;
const generateDescriptor = binding_generator.generateDescriptor;
const getDescriptorPtr = binding_generator.getDescriptorPtr;

const binding_types = @import("runtime").binding_types;
const InterfaceDescriptor = binding_types.InterfaceDescriptor;
const TypeKind = binding_types.TypeKind;
const PrimitiveType = binding_types.PrimitiveType;

// =============================================================================
// Mock Interface Types
// =============================================================================

/// Basic interface with methods and properties
const MockBasicInterface = struct {
    pub const Meta = struct {
        pub const name: [*:0]const u8 = "BasicInterface";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const has_constructor = true;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const methods = .{
            .{ "doSomething", "call_doSomething", 2 },
            .{ "getValue", "call_getValue", 0 },
            .{ "setValue", "call_setValue", 1 },
        };
        pub const properties = .{
            .{ "name", "get_name", @as(?[*:0]const u8, "set_name") },
            .{ "readonlyValue", "get_readonlyValue", @as(?[*:0]const u8, null) },
            .{ "count", "get_count", @as(?[*:0]const u8, "set_count") },
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
    };
};

/// Mixin interface
const MockMixin = struct {
    pub const Meta = struct {
        pub const name: [*:0]const u8 = "TestMixin";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const has_constructor = false;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const methods = .{
            .{ "mixinMethod", "call_mixinMethod", 0 },
        };
        pub const properties = .{
            .{ "mixinProp", "get_mixinProp", @as(?[*:0]const u8, null) },
        };
    };
};

/// Interface without constructor
const MockNoConstructor = struct {
    pub const Meta = struct {
        pub const name: [*:0]const u8 = "NoConstructorInterface";
        pub const is_mixin = false;
        pub const has_constructor = false;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const methods = .{};
        pub const properties = .{};
    };
};

/// Interface with secure context
const MockSecureContext = struct {
    pub const Meta = struct {
        pub const name: [*:0]const u8 = "SecureInterface";
        pub const is_mixin = false;
        pub const has_constructor = true;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const methods = .{};
        pub const properties = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext", .value = {} },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
    };
};

/// Interface exposed in all contexts
const MockAllContexts = struct {
    pub const Meta = struct {
        pub const name: [*:0]const u8 = "AllContextsInterface";
        pub const is_mixin = false;
        pub const has_constructor = true;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const methods = .{};
        pub const properties = .{};
        pub const exposed_in_all_contexts = true;
    };
};

// =============================================================================
// Descriptor Generation Tests
// =============================================================================

test "generateDescriptor - basic interface metadata" {
    const desc = generateDescriptor(MockBasicInterface);

    try testing.expectEqualStrings("BasicInterface", std.mem.span(desc.name));
    try testing.expect(desc.has_constructor);
    try testing.expect(!desc.is_mixin);
    try testing.expect(!desc.is_callback_interface);
    try testing.expect(!desc.is_namespace);
}

test "generateDescriptor - mixin interface" {
    const desc = generateDescriptor(MockMixin);

    try testing.expectEqualStrings("TestMixin", std.mem.span(desc.name));
    try testing.expect(desc.is_mixin);
    try testing.expect(!desc.has_constructor);
}

test "generateDescriptor - no constructor interface" {
    const desc = generateDescriptor(MockNoConstructor);

    try testing.expectEqualStrings("NoConstructorInterface", std.mem.span(desc.name));
    try testing.expect(!desc.has_constructor);
}

test "generateDescriptor - methods extraction" {
    const desc = generateDescriptor(MockBasicInterface);

    try testing.expectEqual(@as(u32, 3), desc.methods_len);
    try testing.expect(desc.methods != null);

    // Verify first method
    const methods = desc.methods.?;
    try testing.expectEqualStrings("doSomething", std.mem.span(methods[0].name.?));
    try testing.expectEqual(@as(u32, 2), methods[0].arguments_len);
}

test "generateDescriptor - properties extraction" {
    const desc = generateDescriptor(MockBasicInterface);

    try testing.expectEqual(@as(u32, 3), desc.properties_len);
    try testing.expect(desc.properties != null);

    // Verify properties
    const properties = desc.properties.?;

    // First property has setter
    try testing.expectEqualStrings("name", std.mem.span(properties[0].name));
    try testing.expect(!properties[0].readonly);

    // Second property is readonly (setter is null)
    try testing.expectEqualStrings("readonlyValue", std.mem.span(properties[1].name));
    try testing.expect(properties[1].readonly);
}

test "generateDescriptor - exposed attribute extraction" {
    const desc = generateDescriptor(MockBasicInterface);

    try testing.expect(desc.exposed != null);
    try testing.expectEqualStrings("Window", std.mem.span(desc.exposed.?));
}

test "generateDescriptor - secure context detection" {
    const desc = generateDescriptor(MockSecureContext);

    try testing.expect(desc.secure_context);
}

test "generateDescriptor - all contexts exposure" {
    const desc = generateDescriptor(MockAllContexts);

    try testing.expect(desc.exposed != null);
    try testing.expectEqualStrings("*", std.mem.span(desc.exposed.?));
}

// =============================================================================
// Pointer and Generator Tests
// =============================================================================

test "getDescriptorPtr - returns valid pointer" {
    const ptr = getDescriptorPtr(MockBasicInterface);

    try testing.expect(@intFromPtr(ptr) != 0);
    try testing.expectEqualStrings("BasicInterface", std.mem.span(ptr.name));
}

test "InterfaceBindingGenerator - Interface type accessible" {
    const Generator = InterfaceBindingGenerator(MockBasicInterface);

    try testing.expect(Generator.Interface == MockBasicInterface);
    try testing.expect(Generator.Meta == MockBasicInterface.Meta);
}

// =============================================================================
// Type Conversion Tests
// =============================================================================

test "zigTypeToDescriptor - void" {
    const Generator = InterfaceBindingGenerator(MockBasicInterface);
    const desc = Generator.zigTypeToDescriptor(void);

    try testing.expectEqual(TypeKind.primitive, desc.kind);
    try testing.expectEqual(PrimitiveType.void, desc.primitive);
}

test "zigTypeToDescriptor - boolean" {
    const Generator = InterfaceBindingGenerator(MockBasicInterface);
    const desc = Generator.zigTypeToDescriptor(bool);

    try testing.expectEqual(TypeKind.primitive, desc.kind);
    try testing.expectEqual(PrimitiveType.boolean, desc.primitive);
}

test "zigTypeToDescriptor - signed integers" {
    const Generator = InterfaceBindingGenerator(MockBasicInterface);

    try testing.expectEqual(PrimitiveType.byte, Generator.zigTypeToDescriptor(i8).primitive);
    try testing.expectEqual(PrimitiveType.short, Generator.zigTypeToDescriptor(i16).primitive);
    try testing.expectEqual(PrimitiveType.long, Generator.zigTypeToDescriptor(i32).primitive);
    try testing.expectEqual(PrimitiveType.long_long, Generator.zigTypeToDescriptor(i64).primitive);
}

test "zigTypeToDescriptor - unsigned integers" {
    const Generator = InterfaceBindingGenerator(MockBasicInterface);

    try testing.expectEqual(PrimitiveType.octet, Generator.zigTypeToDescriptor(u8).primitive);
    try testing.expectEqual(PrimitiveType.unsigned_short, Generator.zigTypeToDescriptor(u16).primitive);
    try testing.expectEqual(PrimitiveType.unsigned_long, Generator.zigTypeToDescriptor(u32).primitive);
    try testing.expectEqual(PrimitiveType.unsigned_long_long, Generator.zigTypeToDescriptor(u64).primitive);
}

test "zigTypeToDescriptor - floats" {
    const Generator = InterfaceBindingGenerator(MockBasicInterface);

    try testing.expectEqual(PrimitiveType.float, Generator.zigTypeToDescriptor(f32).primitive);
    try testing.expectEqual(PrimitiveType.double, Generator.zigTypeToDescriptor(f64).primitive);
}

// =============================================================================
// Edge Case Tests
// =============================================================================

test "generateDescriptor - empty methods and properties" {
    const EmptyInterface = struct {
        pub const Meta = struct {
            pub const name: [*:0]const u8 = "EmptyInterface";
            pub const is_mixin = false;
            pub const has_constructor = false;
            pub const BaseType = ?*anyopaque;
            pub const MixinTypes = &.{};
            pub const methods = .{};
            pub const properties = .{};
        };
    };

    const desc = generateDescriptor(EmptyInterface);

    try testing.expectEqual(@as(u32, 0), desc.methods_len);
    try testing.expectEqual(@as(u32, 0), desc.properties_len);
    try testing.expectEqual(@as(?[*]const binding_types.MethodDescriptor, null), desc.methods);
    try testing.expectEqual(@as(?[*]const binding_types.PropertyDescriptor, null), desc.properties);
}

test "generateDescriptor - minimal interface" {
    const MinimalInterface = struct {
        pub const Meta = struct {
            pub const name: [*:0]const u8 = "Minimal";
            pub const is_mixin = false;
            pub const BaseType = ?*anyopaque;
            pub const MixinTypes = &.{};
        };
    };

    const desc = generateDescriptor(MinimalInterface);

    try testing.expectEqualStrings("Minimal", std.mem.span(desc.name));
    try testing.expect(!desc.is_mixin);
    try testing.expect(!desc.has_constructor); // Default
    try testing.expect(!desc.global); // Default
    try testing.expect(!desc.secure_context); // Default
}
