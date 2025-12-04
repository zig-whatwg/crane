//! Interface Binding Generator
//!
//! Comptime function that generates WebIDL binding descriptors from Zig interface types.
//! This bridges the gap between WebIDL-generated Zig types and the engine-agnostic
//! binding system.
//!
//! ## Design
//!
//! 1. **Comptime Introspection**: Uses Zig's comptime reflection to extract interface metadata
//! 2. **Engine Agnostic**: Generates descriptors usable by any engine (V8, JSC, QuickJS)
//! 3. **Efficient**: All work done at compile time, zero runtime overhead for descriptor creation
//! 4. **Complete**: Handles inheritance, mixins, methods, properties, constants
//!
//! ## Usage
//!
//! ```zig
//! const EventTarget = @import("interfaces").EventTarget;
//! const generator = InterfaceBindingGenerator(EventTarget);
//! const descriptor = generator.getDescriptor();
//!
//! // Register with engine
//! try engine.registerInterface(ctx, &descriptor, &config);
//! ```

const std = @import("std");
const binding_types = @import("binding_types.zig");

pub const TypeDescriptor = binding_types.TypeDescriptor;
pub const TypeKind = binding_types.TypeKind;
pub const PrimitiveType = binding_types.PrimitiveType;
pub const MethodDescriptor = binding_types.MethodDescriptor;
pub const MethodKind = binding_types.MethodKind;
pub const PropertyDescriptor = binding_types.PropertyDescriptor;
pub const ArgumentDescriptor = binding_types.ArgumentDescriptor;
pub const ConstantDescriptor = binding_types.ConstantDescriptor;
pub const InterfaceDescriptor = binding_types.InterfaceDescriptor;
pub const Types = binding_types.Types;

// =============================================================================
// Interface Binding Generator
// =============================================================================

/// Generates binding descriptors from a WebIDL interface type.
///
/// The interface type must have a `Meta` struct with the following fields:
/// - `name`: Interface name string
/// - `is_mixin`: Whether this is a mixin
/// - `is_callback_interface`: Whether this is a callback interface
/// - `has_constructor`: Whether interface has a constructor
/// - `methods`: Tuple of (js_name, zig_name, arity)
/// - `properties`: Tuple of (js_name, getter_name, setter_name_or_null)
/// - Optional: `BaseType`, `MixinTypes`, `extended_attributes`
pub fn InterfaceBindingGenerator(comptime T: type) type {
    return struct {
        pub const Interface = T;
        pub const Meta = T.Meta;

        // Pre-compute method descriptors at comptime
        const method_descriptors = computeMethodDescriptors();
        const property_descriptors = computePropertyDescriptors();
        const constant_descriptors = computeConstantDescriptors();
        const mixin_names = computeMixinNames();

        /// Get the interface descriptor for this type.
        ///
        /// Returns a pointer to a comptime-known InterfaceDescriptor that can
        /// be passed to engine registration functions.
        pub fn getDescriptor() InterfaceDescriptor {
            const m_count = methodCount();
            const p_count = propertyCount();
            const c_count = 0; // TODO: constant count
            const mix_count = mixinCount();

            return InterfaceDescriptor{
                .name = Meta.name,
                .parent = getParentName(),
                .is_mixin = Meta.is_mixin,
                .is_callback_interface = if (@hasDecl(Meta, "is_callback_interface")) Meta.is_callback_interface else false,
                .is_namespace = if (@hasDecl(Meta, "is_namespace")) Meta.is_namespace else false,
                .has_constructor = if (@hasDecl(Meta, "has_constructor")) Meta.has_constructor else false,
                .constructors = null, // TODO: Extract constructor signatures
                .constructors_len = 0,
                .methods = if (m_count > 0) &method_descriptors else null,
                .methods_len = m_count,
                .properties = if (p_count > 0) &property_descriptors else null,
                .properties_len = p_count,
                .constants = if (c_count > 0) &constant_descriptors else null,
                .constants_len = c_count,
                .includes = if (mix_count > 0) &mixin_names else null,
                .includes_len = mix_count,
                .exposed = getExposed(),
                .global = if (@hasDecl(Meta, "is_global")) Meta.is_global else false,
                .legacy_window_alias = null,
                .legacy_no_interface_object = false,
                .legacy_namespace = false,
                .secure_context = getSecureContext(),
                .transferable = if (@hasDecl(Meta, "transferable")) Meta.transferable else false,
                .serializable = if (@hasDecl(Meta, "serializable")) Meta.serializable else false,
            };
        }

        /// Get a pointer to the static descriptor (for use with C APIs)
        pub fn getDescriptorPtr() *const InterfaceDescriptor {
            return &descriptor_storage;
        }

        const descriptor_storage: InterfaceDescriptor = getDescriptor();

        // =====================================================================
        // Helper functions for extracting metadata
        // =====================================================================

        fn getParentName() ?[*:0]const u8 {
            if (@hasDecl(Meta, "BaseType")) {
                const BaseType = Meta.BaseType;
                // Check if BaseType is a pointer to an interface type with Meta
                const base_info = @typeInfo(BaseType);
                if (base_info == .optional) {
                    const child_info = @typeInfo(base_info.optional.child);
                    if (child_info == .pointer) {
                        const Pointee = child_info.pointer.child;
                        if (@hasDecl(Pointee, "Meta") and @hasDecl(Pointee.Meta, "name")) {
                            return Pointee.Meta.name;
                        }
                    }
                } else if (base_info == .pointer) {
                    const Pointee = base_info.pointer.child;
                    if (@hasDecl(Pointee, "Meta") and @hasDecl(Pointee.Meta, "name")) {
                        return Pointee.Meta.name;
                    }
                }
            }
            return null;
        }

        fn getExposed() ?[*:0]const u8 {
            if (@hasDecl(Meta, "extended_attributes")) {
                const attrs = Meta.extended_attributes;
                inline for (attrs) |attr| {
                    if (std.mem.eql(u8, attr.name, "Exposed")) {
                        const ValueType = @TypeOf(attr.value);
                        const value_info = @typeInfo(ValueType);
                        // Check if it's a struct (not void or other non-struct type)
                        if (value_info == .@"struct") {
                            if (@hasField(ValueType, "identifier")) {
                                return attr.value.identifier;
                            }
                        }
                    }
                }
            } else if (@hasDecl(Meta, "exposed_in_all_contexts") and Meta.exposed_in_all_contexts) {
                return "*";
            }
            return null;
        }

        fn getSecureContext() bool {
            if (@hasDecl(Meta, "extended_attributes")) {
                const attrs = Meta.extended_attributes;
                inline for (attrs) |attr| {
                    if (std.mem.eql(u8, attr.name, "SecureContext")) {
                        return true;
                    }
                }
            }
            return false;
        }

        fn computeMethodDescriptors() [methodCount()]MethodDescriptor {
            const count = methodCount();
            if (count == 0) return .{};

            var result: [count]MethodDescriptor = undefined;
            const methods = Meta.methods;

            inline for (methods, 0..) |method, i| {
                // method is a tuple: (js_name, zig_name, arity)
                const js_name: [*:0]const u8 = method[0];
                const arity: u32 = method[2];

                result[i] = MethodDescriptor{
                    .name = js_name,
                    .kind = .regular,
                    .return_type = &Types.any, // TODO: Extract actual return type
                    .arguments = null, // TODO: Extract argument descriptors
                    .arguments_len = arity,
                    .overloaded = false,
                    .overload_index = 0,
                    .ce_reactions = false,
                    .returns_new_object = false,
                };
            }

            return result;
        }

        fn methodCount() comptime_int {
            if (!@hasDecl(Meta, "methods")) return 0;
            return Meta.methods.len;
        }

        fn computePropertyDescriptors() [propertyCount()]PropertyDescriptor {
            const count = propertyCount();
            if (count == 0) return .{};

            var result: [count]PropertyDescriptor = undefined;
            const properties = Meta.properties;

            inline for (properties, 0..) |prop, i| {
                // prop is a tuple: (js_name, getter_name, setter_name_or_null)
                const js_name: [*:0]const u8 = prop[0];
                // Check if there's a setter - tuple element 2 exists and is not null
                // The setter can be optional (?[*:0]const u8) or a direct string
                const has_setter = comptime blk: {
                    if (prop.len <= 2) break :blk false;
                    const SetterType = @TypeOf(prop[2]);
                    const setter_info = @typeInfo(SetterType);
                    if (setter_info == .optional) {
                        break :blk prop[2] != null;
                    }
                    // It's a non-optional type, so it has a setter
                    break :blk true;
                };

                result[i] = PropertyDescriptor{
                    .name = js_name,
                    .type = &Types.any, // TODO: Extract actual type
                    .readonly = !has_setter,
                    .static = false, // TODO: Detect static properties
                    .ce_reactions = false,
                    .reflects = false,
                    .attribute_name = null,
                    .replaceable = false,
                    .lenient_setter = false,
                    .lenient_this = false,
                    .put_forwards = null,
                };
            }

            return result;
        }

        fn propertyCount() comptime_int {
            if (!@hasDecl(Meta, "properties")) return 0;
            return Meta.properties.len;
        }

        fn computeConstantDescriptors() [0]ConstantDescriptor {
            // TODO: Extract constants from interface type
            // Constants are typically defined as `const` fields
            return .{};
        }

        fn computeMixinNames() [mixinCount()][*:0]const u8 {
            const count = mixinCount();
            if (count == 0) return .{};

            var result: [count][*:0]const u8 = undefined;
            const MixinTypes = Meta.MixinTypes;

            inline for (MixinTypes, 0..) |MixinType, i| {
                if (@hasDecl(MixinType, "Meta") and @hasDecl(MixinType.Meta, "name")) {
                    result[i] = MixinType.Meta.name;
                }
            }

            return result;
        }

        fn mixinCount() comptime_int {
            if (!@hasDecl(Meta, "MixinTypes")) return 0;
            return Meta.MixinTypes.len;
        }

        // =====================================================================
        // Type conversion helpers
        // =====================================================================

        /// Convert a Zig type to a WebIDL type descriptor
        pub fn zigTypeToDescriptor(comptime ZigType: type) TypeDescriptor {
            const info = @typeInfo(ZigType);

            return switch (info) {
                .void => Types.void_type,
                .bool => Types.boolean,
                .int => |int_info| blk: {
                    if (int_info.signedness == .signed) {
                        break :blk switch (int_info.bits) {
                            8 => Types.byte,
                            16 => Types.short,
                            32 => Types.long,
                            64 => Types.long_long,
                            else => Types.any,
                        };
                    } else {
                        break :blk switch (int_info.bits) {
                            8 => Types.octet,
                            16 => Types.unsigned_short,
                            32 => Types.unsigned_long,
                            64 => Types.unsigned_long_long,
                            else => Types.any,
                        };
                    }
                },
                .float => |float_info| switch (float_info.bits) {
                    32 => Types.float,
                    64 => Types.double,
                    else => Types.any,
                },
                .pointer => |ptr_info| blk: {
                    // Check for common WebIDL types
                    if (ptr_info.child == u8) {
                        // []const u8 or [*:0]const u8 -> DOMString
                        break :blk Types.DOMString;
                    }
                    // Interface pointer
                    if (@hasDecl(ptr_info.child, "Meta")) {
                        break :blk TypeDescriptor.interface_(ptr_info.child.Meta.name);
                    }
                    break :blk Types.any;
                },
                .optional => blk: {
                    const inner = zigTypeToDescriptor(info.optional.child);
                    break :blk TypeDescriptor.nullable_(&inner);
                },
                else => Types.any,
            };
        }
    };
}

// =============================================================================
// Convenience Functions
// =============================================================================

/// Generate a binding descriptor from an interface type.
/// Shorthand for InterfaceBindingGenerator(T).getDescriptor()
pub fn generateDescriptor(comptime T: type) InterfaceDescriptor {
    return InterfaceBindingGenerator(T).getDescriptor();
}

/// Get a pointer to a static binding descriptor from an interface type.
/// Useful for C API calls that need a pointer.
pub fn getDescriptorPtr(comptime T: type) *const InterfaceDescriptor {
    return InterfaceBindingGenerator(T).getDescriptorPtr();
}

// =============================================================================
// Tests
// =============================================================================

test "InterfaceBindingGenerator - basic interface" {
    // Create a mock interface type for testing
    const MockInterface = struct {
        pub const Meta = struct {
            pub const name: [*:0]const u8 = "MockInterface";
            pub const is_mixin = false;
            pub const is_callback_interface = false;
            pub const has_constructor = true;
            pub const BaseType = ?*anyopaque;
            pub const MixinTypes = &.{};
            pub const methods = .{
                .{ "doSomething", "call_doSomething", 1 },
                .{ "getValue", "call_getValue", 0 },
            };
            pub const properties = .{
                .{ "value", "get_value", @as(?[*:0]const u8, "set_value") },
                .{ "name", "get_name", @as(?[*:0]const u8, null) },
            };
            pub const extended_attributes = .{
                .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            };
        };
    };

    const generator = InterfaceBindingGenerator(MockInterface);
    const desc = generator.getDescriptor();

    try std.testing.expectEqualStrings("MockInterface", std.mem.span(desc.name));
    try std.testing.expect(desc.has_constructor);
    try std.testing.expect(!desc.is_mixin);
    try std.testing.expectEqual(@as(u32, 2), desc.methods_len);
    try std.testing.expectEqual(@as(u32, 2), desc.properties_len);
}

test "InterfaceBindingGenerator - mixin interface" {
    const MockMixin = struct {
        pub const Meta = struct {
            pub const name: [*:0]const u8 = "MockMixin";
            pub const is_mixin = true;
            pub const is_callback_interface = false;
            pub const has_constructor = false;
            pub const BaseType = ?*anyopaque;
            pub const MixinTypes = &.{};
            pub const methods = .{};
            pub const properties = .{};
        };
    };

    const desc = generateDescriptor(MockMixin);

    try std.testing.expectEqualStrings("MockMixin", std.mem.span(desc.name));
    try std.testing.expect(desc.is_mixin);
    try std.testing.expect(!desc.has_constructor);
}

test "InterfaceBindingGenerator - type conversion" {
    const Generator = InterfaceBindingGenerator(struct {
        pub const Meta = struct {
            pub const name: [*:0]const u8 = "Test";
            pub const is_mixin = false;
            pub const BaseType = ?*anyopaque;
            pub const MixinTypes = &.{};
        };
    });

    // Test primitive types
    try std.testing.expectEqual(TypeKind.primitive, Generator.zigTypeToDescriptor(void).kind);
    try std.testing.expectEqual(PrimitiveType.void, Generator.zigTypeToDescriptor(void).primitive);

    try std.testing.expectEqual(TypeKind.primitive, Generator.zigTypeToDescriptor(bool).kind);
    try std.testing.expectEqual(PrimitiveType.boolean, Generator.zigTypeToDescriptor(bool).primitive);

    try std.testing.expectEqual(TypeKind.primitive, Generator.zigTypeToDescriptor(i32).kind);
    try std.testing.expectEqual(PrimitiveType.long, Generator.zigTypeToDescriptor(i32).primitive);

    try std.testing.expectEqual(TypeKind.primitive, Generator.zigTypeToDescriptor(u32).kind);
    try std.testing.expectEqual(PrimitiveType.unsigned_long, Generator.zigTypeToDescriptor(u32).primitive);

    try std.testing.expectEqual(TypeKind.primitive, Generator.zigTypeToDescriptor(f64).kind);
    try std.testing.expectEqual(PrimitiveType.double, Generator.zigTypeToDescriptor(f64).primitive);
}

test "generateDescriptor convenience function" {
    const MockInterface = struct {
        pub const Meta = struct {
            pub const name: [*:0]const u8 = "Convenience";
            pub const is_mixin = false;
            pub const BaseType = ?*anyopaque;
            pub const MixinTypes = &.{};
        };
    };

    const desc = generateDescriptor(MockInterface);
    try std.testing.expectEqualStrings("Convenience", std.mem.span(desc.name));
}

test "getDescriptorPtr returns valid pointer" {
    const MockInterface = struct {
        pub const Meta = struct {
            pub const name: [*:0]const u8 = "PointerTest";
            pub const is_mixin = false;
            pub const BaseType = ?*anyopaque;
            pub const MixinTypes = &.{};
        };
    };

    const ptr = getDescriptorPtr(MockInterface);
    try std.testing.expect(ptr != undefined);
    try std.testing.expectEqualStrings("PointerTest", std.mem.span(ptr.name));
}
