//! Descriptor Types Unit Tests
//!
//! Tests for WebIDL binding descriptor types:
//! - TypeDescriptor
//! - MethodDescriptor
//! - PropertyDescriptor
//! - InterfaceDescriptor
//! - DictionaryDescriptor
//! - EnumDescriptor
//! - CallbackDescriptor

const std = @import("std");
const testing = std.testing;

const binding_types = @import("runtime").binding_types;
const TypeDescriptor = binding_types.TypeDescriptor;
const TypeKind = binding_types.TypeKind;
const PrimitiveType = binding_types.PrimitiveType;
const MethodDescriptor = binding_types.MethodDescriptor;
const MethodKind = binding_types.MethodKind;
const PropertyDescriptor = binding_types.PropertyDescriptor;
const ArgumentDescriptor = binding_types.ArgumentDescriptor;
const ConstantDescriptor = binding_types.ConstantDescriptor;
const InterfaceDescriptor = binding_types.InterfaceDescriptor;
const DictionaryDescriptor = binding_types.DictionaryDescriptor;
const DictionaryMemberDescriptor = binding_types.DictionaryMemberDescriptor;
const EnumDescriptor = binding_types.EnumDescriptor;
const CallbackDescriptor = binding_types.CallbackDescriptor;
const Types = binding_types.Types;

// =============================================================================
// TypeDescriptor Tests
// =============================================================================

test "TypeDescriptor - primitive convenience constructors" {
    const void_type = Types.void_type;
    try testing.expectEqual(TypeKind.primitive, void_type.kind);
    try testing.expectEqual(PrimitiveType.void, void_type.primitive);

    const bool_type = Types.boolean;
    try testing.expectEqual(TypeKind.primitive, bool_type.kind);
    try testing.expectEqual(PrimitiveType.boolean, bool_type.primitive);

    const string_type = Types.DOMString;
    try testing.expectEqual(TypeKind.primitive, string_type.kind);
    try testing.expectEqual(PrimitiveType.DOMString, string_type.primitive);
}

test "TypeDescriptor - interface type construction" {
    const interface_type = TypeDescriptor.interface_("Blob");

    try testing.expectEqual(TypeKind.interface, interface_type.kind);
    try testing.expectEqualStrings("Blob", std.mem.span(interface_type.type_name.?));
}

test "TypeDescriptor - sequence type construction" {
    const inner = Types.DOMString;
    const seq_type = TypeDescriptor.sequence_(&inner);

    try testing.expectEqual(TypeKind.sequence, seq_type.kind);
    try testing.expectEqual(&inner, seq_type.inner_type.?);
}

test "TypeDescriptor - promise type construction" {
    const inner = Types.void_type;
    const promise_type = TypeDescriptor.promise_(&inner);

    try testing.expectEqual(TypeKind.promise, promise_type.kind);
    try testing.expectEqual(&inner, promise_type.inner_type.?);
}

test "TypeDescriptor - nullable type construction" {
    const inner = Types.DOMString;
    const nullable_type = TypeDescriptor.nullable_(&inner);

    try testing.expectEqual(TypeKind.nullable, nullable_type.kind);
    try testing.expectEqual(&inner, nullable_type.inner_type.?);
}

test "TypeDescriptor - buffer types" {
    try testing.expectEqual(TypeKind.array_buffer, Types.ArrayBuffer.kind);
    try testing.expectEqual(TypeKind.array_buffer_view, Types.ArrayBufferView.kind);
    try testing.expectEqual(TypeKind.data_view, Types.DataView.kind);
    try testing.expectEqual(TypeKind.uint8_array, Types.Uint8Array.kind);
    try testing.expectEqual(TypeKind.int32_array, Types.Int32Array.kind);
    try testing.expectEqual(TypeKind.float64_array, Types.Float64Array.kind);
}

test "TypeDescriptor - is extern struct" {
    const info = @typeInfo(TypeDescriptor);
    try testing.expect(info == .@"struct");
    try testing.expect(info.@"struct".layout == .@"extern");
}

// =============================================================================
// MethodDescriptor Tests
// =============================================================================

test "MethodDescriptor - default values" {
    const desc = MethodDescriptor{
        .name = "testMethod",
        .return_type = &Types.void_type,
    };

    try testing.expectEqual(MethodKind.regular, desc.kind);
    try testing.expect(!desc.overloaded);
    try testing.expectEqual(@as(u8, 0), desc.overload_index);
    try testing.expect(!desc.ce_reactions);
    try testing.expect(!desc.returns_new_object);
}

test "MethodDescriptor - static method" {
    const desc = MethodDescriptor{
        .name = "staticMethod",
        .kind = .static,
        .return_type = &Types.DOMString,
    };

    try testing.expectEqual(MethodKind.static, desc.kind);
}

test "MethodDescriptor - getter operation" {
    const desc = MethodDescriptor{
        .name = null, // Special operations often have null names
        .kind = .getter,
        .return_type = &Types.any,
    };

    try testing.expectEqual(MethodKind.getter, desc.kind);
    try testing.expectEqual(@as(?[*:0]const u8, null), desc.name);
}

test "MethodDescriptor - is extern struct" {
    const info = @typeInfo(MethodDescriptor);
    try testing.expect(info == .@"struct");
    try testing.expect(info.@"struct".layout == .@"extern");
}

// =============================================================================
// PropertyDescriptor Tests
// =============================================================================

test "PropertyDescriptor - default values" {
    const desc = PropertyDescriptor{
        .name = "testProp",
        .type = &Types.DOMString,
    };

    try testing.expect(!desc.readonly);
    try testing.expect(!desc.static);
    try testing.expect(!desc.ce_reactions);
    try testing.expect(!desc.reflects);
    try testing.expect(!desc.replaceable);
    try testing.expect(!desc.lenient_setter);
    try testing.expect(!desc.lenient_this);
    try testing.expectEqual(@as(?[*:0]const u8, null), desc.put_forwards);
}

test "PropertyDescriptor - readonly property" {
    const desc = PropertyDescriptor{
        .name = "readonlyProp",
        .type = &Types.long,
        .readonly = true,
    };

    try testing.expect(desc.readonly);
}

test "PropertyDescriptor - static property" {
    const desc = PropertyDescriptor{
        .name = "staticProp",
        .type = &Types.boolean,
        .static = true,
    };

    try testing.expect(desc.static);
}

test "PropertyDescriptor - reflecting attribute" {
    const desc = PropertyDescriptor{
        .name = "id",
        .type = &Types.DOMString,
        .reflects = true,
        .attribute_name = "id",
    };

    try testing.expect(desc.reflects);
    try testing.expectEqualStrings("id", std.mem.span(desc.attribute_name.?));
}

test "PropertyDescriptor - is extern struct" {
    const info = @typeInfo(PropertyDescriptor);
    try testing.expect(info == .@"struct");
    try testing.expect(info.@"struct".layout == .@"extern");
}

// =============================================================================
// ArgumentDescriptor Tests
// =============================================================================

test "ArgumentDescriptor - required argument" {
    const desc = ArgumentDescriptor{
        .name = "arg1",
        .type = &Types.DOMString,
    };

    try testing.expect(!desc.optional);
    try testing.expect(!desc.has_default);
    try testing.expect(!desc.variadic);
}

test "ArgumentDescriptor - optional argument" {
    const desc = ArgumentDescriptor{
        .name = "optArg",
        .type = &Types.long,
        .optional = true,
    };

    try testing.expect(desc.optional);
}

test "ArgumentDescriptor - default value" {
    const desc = ArgumentDescriptor{
        .name = "defaultArg",
        .type = &Types.DOMString,
        .optional = true,
        .has_default = true,
        .default_value = "\"\"",
    };

    try testing.expect(desc.has_default);
    try testing.expectEqualStrings("\"\"", std.mem.span(desc.default_value.?));
}

test "ArgumentDescriptor - variadic argument" {
    const desc = ArgumentDescriptor{
        .name = "rest",
        .type = &Types.any,
        .variadic = true,
    };

    try testing.expect(desc.variadic);
}

test "ArgumentDescriptor - is extern struct" {
    const info = @typeInfo(ArgumentDescriptor);
    try testing.expect(info == .@"struct");
    try testing.expect(info.@"struct".layout == .@"extern");
}

// =============================================================================
// ConstantDescriptor Tests
// =============================================================================

test "ConstantDescriptor - integer constant" {
    const desc = ConstantDescriptor{
        .name = "MAX_VALUE",
        .type = &Types.unsigned_long,
        .value = "4294967295",
    };

    try testing.expectEqualStrings("MAX_VALUE", std.mem.span(desc.name));
    try testing.expectEqualStrings("4294967295", std.mem.span(desc.value));
}

test "ConstantDescriptor - string constant" {
    const desc = ConstantDescriptor{
        .name = "DEFAULT_NAME",
        .type = &Types.DOMString,
        .value = "\"default\"",
    };

    try testing.expectEqualStrings("\"default\"", std.mem.span(desc.value));
}

test "ConstantDescriptor - is extern struct" {
    const info = @typeInfo(ConstantDescriptor);
    try testing.expect(info == .@"struct");
    try testing.expect(info.@"struct".layout == .@"extern");
}

// =============================================================================
// InterfaceDescriptor Tests
// =============================================================================

test "InterfaceDescriptor - minimal interface" {
    const desc = InterfaceDescriptor{
        .name = "MinimalInterface",
    };

    try testing.expectEqualStrings("MinimalInterface", std.mem.span(desc.name));
    try testing.expectEqual(@as(?[*:0]const u8, null), desc.parent);
    try testing.expect(!desc.is_mixin);
    try testing.expect(!desc.is_callback_interface);
    try testing.expect(!desc.is_namespace);
    try testing.expect(!desc.has_constructor);
}

test "InterfaceDescriptor - with parent" {
    const desc = InterfaceDescriptor{
        .name = "ChildInterface",
        .parent = "ParentInterface",
        .has_constructor = true,
    };

    try testing.expectEqualStrings("ParentInterface", std.mem.span(desc.parent.?));
}

test "InterfaceDescriptor - namespace" {
    const desc = InterfaceDescriptor{
        .name = "Math",
        .is_namespace = true,
    };

    try testing.expect(desc.is_namespace);
    try testing.expect(!desc.has_constructor); // Namespaces don't have constructors
}

test "InterfaceDescriptor - extended attributes" {
    const desc = InterfaceDescriptor{
        .name = "SecureInterface",
        .exposed = "Window",
        .global = false,
        .secure_context = true,
        .transferable = true,
        .serializable = true,
    };

    try testing.expectEqualStrings("Window", std.mem.span(desc.exposed.?));
    try testing.expect(desc.secure_context);
    try testing.expect(desc.transferable);
    try testing.expect(desc.serializable);
}

test "InterfaceDescriptor - is extern struct" {
    const info = @typeInfo(InterfaceDescriptor);
    try testing.expect(info == .@"struct");
    try testing.expect(info.@"struct".layout == .@"extern");
}

// =============================================================================
// DictionaryDescriptor Tests
// =============================================================================

test "DictionaryDescriptor - basic dictionary" {
    const desc = DictionaryDescriptor{
        .name = "RequestInit",
    };

    try testing.expectEqualStrings("RequestInit", std.mem.span(desc.name));
    try testing.expectEqual(@as(?[*:0]const u8, null), desc.parent);
}

test "DictionaryDescriptor - with parent" {
    const desc = DictionaryDescriptor{
        .name = "ExtendedInit",
        .parent = "RequestInit",
    };

    try testing.expectEqualStrings("RequestInit", std.mem.span(desc.parent.?));
}

test "DictionaryMemberDescriptor - required member" {
    const desc = DictionaryMemberDescriptor{
        .name = "method",
        .type = &Types.DOMString,
        .required = true,
    };

    try testing.expect(desc.required);
    try testing.expectEqual(@as(?[*:0]const u8, null), desc.default_value);
}

test "DictionaryMemberDescriptor - optional with default" {
    const desc = DictionaryMemberDescriptor{
        .name = "cache",
        .type = &Types.DOMString,
        .required = false,
        .default_value = "\"default\"",
    };

    try testing.expect(!desc.required);
    try testing.expectEqualStrings("\"default\"", std.mem.span(desc.default_value.?));
}

test "DictionaryDescriptor - is extern struct" {
    const info = @typeInfo(DictionaryDescriptor);
    try testing.expect(info == .@"struct");
    try testing.expect(info.@"struct".layout == .@"extern");
}

// =============================================================================
// EnumDescriptor Tests
// =============================================================================

test "EnumDescriptor - basic enum" {
    const values = [_][*:0]const u8{ "auto", "ltr", "rtl" };
    const desc = EnumDescriptor{
        .name = "TextDirectionality",
        .values = &values,
        .values_len = 3,
    };

    try testing.expectEqualStrings("TextDirectionality", std.mem.span(desc.name));
    try testing.expectEqual(@as(u32, 3), desc.values_len);
    try testing.expectEqualStrings("auto", std.mem.span(desc.values[0]));
    try testing.expectEqualStrings("rtl", std.mem.span(desc.values[2]));
}

test "EnumDescriptor - is extern struct" {
    const info = @typeInfo(EnumDescriptor);
    try testing.expect(info == .@"struct");
    try testing.expect(info.@"struct".layout == .@"extern");
}

// =============================================================================
// CallbackDescriptor Tests
// =============================================================================

test "CallbackDescriptor - basic callback" {
    const desc = CallbackDescriptor{
        .name = "EventListener",
        .return_type = &Types.void_type,
    };

    try testing.expectEqualStrings("EventListener", std.mem.span(desc.name));
    try testing.expectEqual(@as(u32, 0), desc.arguments_len);
}

test "CallbackDescriptor - with arguments" {
    const args = [_]ArgumentDescriptor{
        .{
            .name = "event",
            .type = &Types.any,
        },
    };

    const desc = CallbackDescriptor{
        .name = "EventHandler",
        .return_type = &Types.any,
        .arguments = &args,
        .arguments_len = 1,
    };

    try testing.expectEqual(@as(u32, 1), desc.arguments_len);
}

test "CallbackDescriptor - is extern struct" {
    const info = @typeInfo(CallbackDescriptor);
    try testing.expect(info == .@"struct");
    try testing.expect(info.@"struct".layout == .@"extern");
}
