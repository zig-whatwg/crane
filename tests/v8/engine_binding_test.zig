//! V8 EngineBinding Integration Tests
//!
//! Tests for the V8 EngineBinding VTable implementation.
//! These tests verify:
//! - EngineBinding operations are properly wired up
//! - Interface registration works correctly
//! - Value conversion through EngineBinding works
//! - Error handling through EngineBinding
//! - Async support (iterators, streams)
//! - Structured clone support
//!
//! NOTE: Full integration tests require V8 initialization.
//! These tests focus on verifying the binding layer compiles and has correct structure.

const std = @import("std");
const testing = std.testing;

// Import runtime modules
const runtime = @import("runtime");
const binding_types = runtime.binding_types;
const engine_binding = runtime.engine_binding;

// Import V8 module
const v8 = @import("v8");

// ============================================================================
// VTable Structure Tests
// ============================================================================

test "v8_engine_interface - exists and has correct name" {
    try testing.expectEqualStrings("V8", v8.v8_engine_interface.name);
}

test "v8_engine_interface - has core EngineInterface functions" {
    const interface = v8.v8_engine_interface;

    // Core EngineInterface functions are non-optional (always present)
    // We just verify they're callable by checking the type exists
    _ = @TypeOf(interface.wrapAsyncIterator);
    _ = @TypeOf(interface.createPromise);
    _ = @TypeOf(interface.resolvePromise);
    _ = @TypeOf(interface.rejectPromise);
    _ = @TypeOf(interface.getPromiseObject);

    // Check optional but implemented functions (these are ?*const fn types)
    try testing.expect(interface.createString != null);
    try testing.expect(interface.createArrayBuffer != null);
    try testing.expect(interface.createUint8Array != null);
    try testing.expect(interface.parseJson != null);
    try testing.expect(interface.wrapInstance != null);
    try testing.expect(interface.isString != null);
    try testing.expect(interface.extractString != null);
    try testing.expect(interface.createStringArray != null);
    try testing.expect(interface.createEventLoop != null);
    try testing.expect(interface.destroyEventLoop != null);

    // Check callback wrapper functions
    try testing.expect(interface.createCallbackWrapper != null);
    try testing.expect(interface.invokeCallback != null);
    try testing.expect(interface.destroyCallbackWrapper != null);

    // Check GC and scheduling
    try testing.expect(interface.requestGarbageCollection != null);
    try testing.expect(interface.scheduleOnMainThread != null);

    // Check stream support
    try testing.expect(interface.invokeStreamCallback != null);
    try testing.expect(interface.getWrapperForInstance != null);
    try testing.expect(interface.chainPromiseHandlers != null);

    // Check script/module execution support
    try testing.expect(interface.compileScript != null);
    try testing.expect(interface.runScript != null);
    try testing.expect(interface.compileModule != null);
    try testing.expect(interface.runModule != null);
    try testing.expect(interface.disposeScript != null);
    try testing.expect(interface.disposeModule != null);
    try testing.expect(interface.runModuleAsync != null);
    try testing.expect(interface.hasTopLevelAwait != null);
}

// ============================================================================
// Type Descriptor Tests
// ============================================================================

test "TypeDescriptor - primitive types" {
    // Test primitive type descriptor creation using helper methods
    const bool_desc = binding_types.TypeDescriptor.primitive_(.boolean);
    try testing.expectEqual(binding_types.TypeKind.primitive, bool_desc.kind);
    try testing.expectEqual(binding_types.PrimitiveType.boolean, bool_desc.primitive);

    const long_desc = binding_types.TypeDescriptor.primitive_(.long);
    try testing.expectEqual(binding_types.PrimitiveType.long, long_desc.primitive);

    const double_desc = binding_types.TypeDescriptor.primitive_(.double);
    try testing.expectEqual(binding_types.PrimitiveType.double, double_desc.primitive);
}

test "TypeDescriptor - string types" {
    const domstring_desc = binding_types.Types.DOMString;
    try testing.expectEqual(binding_types.PrimitiveType.DOMString, domstring_desc.primitive);

    const usvstring_desc = binding_types.Types.USVString;
    try testing.expectEqual(binding_types.PrimitiveType.USVString, usvstring_desc.primitive);
}

test "TypeDescriptor - nullable types" {
    const inner_desc = binding_types.TypeDescriptor.primitive_(.long);
    const nullable_desc = binding_types.TypeDescriptor.nullable_(&inner_desc);

    try testing.expectEqual(binding_types.TypeKind.nullable, nullable_desc.kind);
    try testing.expect(nullable_desc.inner_type != null);
    try testing.expectEqual(binding_types.PrimitiveType.long, nullable_desc.inner_type.?.primitive);
}

test "TypeDescriptor - interface types" {
    const interface_desc = binding_types.TypeDescriptor.interface_("Element");

    try testing.expectEqual(binding_types.TypeKind.interface, interface_desc.kind);
    try testing.expectEqualStrings("Element", std.mem.span(interface_desc.type_name.?));
}

test "TypeDescriptor - sequence types" {
    const inner_desc = binding_types.Types.DOMString;
    const sequence_desc = binding_types.TypeDescriptor.sequence_(&inner_desc);

    try testing.expectEqual(binding_types.TypeKind.sequence, sequence_desc.kind);
    try testing.expect(sequence_desc.inner_type != null);
}

test "TypeDescriptor - promise types" {
    const inner_desc = binding_types.Types.void_type;
    const promise_desc = binding_types.TypeDescriptor.promise_(&inner_desc);

    try testing.expectEqual(binding_types.TypeKind.promise, promise_desc.kind);
    try testing.expect(promise_desc.inner_type != null);
}

// ============================================================================
// Interface Descriptor Tests
// ============================================================================

test "InterfaceDescriptor - basic properties" {
    const desc = binding_types.InterfaceDescriptor{
        .name = "TestInterface",
        .has_constructor = true,
    };

    try testing.expectEqualStrings("TestInterface", std.mem.span(desc.name));
    try testing.expect(desc.parent == null);
    try testing.expect(!desc.is_mixin);
    try testing.expect(desc.has_constructor);
}

test "InterfaceDescriptor - with parent" {
    const desc = binding_types.InterfaceDescriptor{
        .name = "HTMLElement",
        .parent = "Element",
        .has_constructor = true,
    };

    try testing.expect(desc.parent != null);
    try testing.expectEqualStrings("Element", std.mem.span(desc.parent.?));
}

test "InterfaceDescriptor - mixin" {
    const desc = binding_types.InterfaceDescriptor{
        .name = "ParentNode",
        .is_mixin = true,
    };

    try testing.expect(desc.is_mixin);
    try testing.expect(!desc.has_constructor);
}

test "InterfaceDescriptor - namespace" {
    const desc = binding_types.InterfaceDescriptor{
        .name = "console",
        .is_namespace = true,
    };

    try testing.expect(desc.is_namespace);
    try testing.expect(!desc.has_constructor);
}

// ============================================================================
// Method Descriptor Tests
// ============================================================================

test "MethodDescriptor - basic method" {
    const ret_type = binding_types.Types.void_type;

    const method = binding_types.MethodDescriptor{
        .name = "focus",
        .return_type = &ret_type,
    };

    try testing.expectEqualStrings("focus", std.mem.span(method.name.?));
    try testing.expect(method.kind == .regular);
    try testing.expectEqual(@as(u32, 0), method.arguments_len);
}

test "MethodDescriptor - static method" {
    const ret_type = binding_types.TypeDescriptor.interface_("Element");

    const method = binding_types.MethodDescriptor{
        .name = "createElement",
        .kind = .static,
        .return_type = &ret_type,
    };

    try testing.expect(method.kind == .static);
}

test "MethodDescriptor - getter" {
    const ret_type = binding_types.Types.DOMString;

    const method = binding_types.MethodDescriptor{
        .name = null, // getters don't have names in the traditional sense
        .kind = .getter,
        .return_type = &ret_type,
    };

    try testing.expect(method.kind == .getter);
}

// ============================================================================
// Property Descriptor Tests
// ============================================================================

test "PropertyDescriptor - readonly property" {
    const prop_type = binding_types.Types.DOMString;

    const prop = binding_types.PropertyDescriptor{
        .name = "nodeName",
        .type = &prop_type,
        .readonly = true,
    };

    try testing.expectEqualStrings("nodeName", std.mem.span(prop.name));
    try testing.expect(prop.readonly);
}

test "PropertyDescriptor - readwrite property" {
    const prop_type = binding_types.Types.DOMString;

    const prop = binding_types.PropertyDescriptor{
        .name = "innerHTML",
        .type = &prop_type,
        .readonly = false,
    };

    try testing.expect(!prop.readonly);
}

test "PropertyDescriptor - reflecting property" {
    const prop_type = binding_types.Types.DOMString;

    const prop = binding_types.PropertyDescriptor{
        .name = "id",
        .type = &prop_type,
        .reflects = true,
        .attribute_name = "id",
    };

    try testing.expect(prop.reflects);
    try testing.expectEqualStrings("id", std.mem.span(prop.attribute_name.?));
}

// ============================================================================
// Dictionary Descriptor Tests
// ============================================================================

test "DictionaryDescriptor - basic" {
    const desc = binding_types.DictionaryDescriptor{
        .name = "EventInit",
    };

    try testing.expectEqualStrings("EventInit", std.mem.span(desc.name));
    try testing.expect(desc.parent == null);
}

test "DictionaryDescriptor - with parent" {
    const desc = binding_types.DictionaryDescriptor{
        .name = "CustomEventInit",
        .parent = "EventInit",
    };

    try testing.expect(desc.parent != null);
    try testing.expectEqualStrings("EventInit", std.mem.span(desc.parent.?));
}

// ============================================================================
// Enum Descriptor Tests
// ============================================================================

test "EnumDescriptor - basic" {
    const values = [_][*:0]const u8{ "left", "right", "center" };

    const desc = binding_types.EnumDescriptor{
        .name = "TextAlign",
        .values = &values,
        .values_len = 3,
    };

    try testing.expectEqualStrings("TextAlign", std.mem.span(desc.name));
    try testing.expectEqual(@as(u32, 3), desc.values_len);
}

// ============================================================================
// Callback Descriptor Tests
// ============================================================================

test "CallbackDescriptor - basic" {
    const ret_type = binding_types.Types.void_type;

    const desc = binding_types.CallbackDescriptor{
        .name = "EventListener",
        .return_type = &ret_type,
    };

    try testing.expectEqualStrings("EventListener", std.mem.span(desc.name));
    try testing.expectEqual(@as(u32, 0), desc.arguments_len);
}

// ============================================================================
// V8-specific Module Tests
// ============================================================================

test "v8 conversions module - exists" {
    _ = v8.conversions;
}

test "v8 ffi module - has basic types" {
    _ = v8.Isolate;
    _ = v8.Context;
    _ = v8.Value;
    _ = v8.Object;
    _ = v8.Function;
    _ = v8.String;
}

test "v8 promise module - exists" {
    _ = v8.Promise;
    _ = v8.invokeCallback;
}

test "v8 template registry - exists" {
    _ = v8.template_registry;
}

test "v8 wrapper cache - exists" {
    _ = v8.WrapperCache;
}

test "v8 event loop - exists" {
    _ = v8.V8EventLoop;
}

// ============================================================================
// Pre-defined Types Tests
// ============================================================================

test "Types - all primitives defined" {
    _ = binding_types.Types.void_type;
    _ = binding_types.Types.boolean;
    _ = binding_types.Types.byte;
    _ = binding_types.Types.octet;
    _ = binding_types.Types.short;
    _ = binding_types.Types.unsigned_short;
    _ = binding_types.Types.long;
    _ = binding_types.Types.unsigned_long;
    _ = binding_types.Types.long_long;
    _ = binding_types.Types.unsigned_long_long;
    _ = binding_types.Types.float;
    _ = binding_types.Types.unrestricted_float;
    _ = binding_types.Types.double;
    _ = binding_types.Types.unrestricted_double;
    _ = binding_types.Types.bigint;
    _ = binding_types.Types.DOMString;
    _ = binding_types.Types.ByteString;
    _ = binding_types.Types.USVString;
    _ = binding_types.Types.object;
    _ = binding_types.Types.any;
    _ = binding_types.Types.undefined;
}

test "Types - buffer types defined" {
    _ = binding_types.Types.ArrayBuffer;
    _ = binding_types.Types.ArrayBufferView;
    _ = binding_types.Types.DataView;
    _ = binding_types.Types.Uint8Array;
    _ = binding_types.Types.Uint16Array;
    _ = binding_types.Types.Uint32Array;
    _ = binding_types.Types.Int8Array;
    _ = binding_types.Types.Int16Array;
    _ = binding_types.Types.Int32Array;
    _ = binding_types.Types.Float32Array;
    _ = binding_types.Types.Float64Array;
}

// ============================================================================
// Extern Struct Layout Tests
// ============================================================================

test "extern struct layout - for FFI compatibility" {
    // Verify structs are extern for FFI
    try testing.expect(@typeInfo(binding_types.TypeDescriptor).@"struct".layout == .@"extern");
    try testing.expect(@typeInfo(binding_types.MethodDescriptor).@"struct".layout == .@"extern");
    try testing.expect(@typeInfo(binding_types.PropertyDescriptor).@"struct".layout == .@"extern");
    try testing.expect(@typeInfo(binding_types.InterfaceDescriptor).@"struct".layout == .@"extern");
    try testing.expect(@typeInfo(binding_types.DictionaryDescriptor).@"struct".layout == .@"extern");
    try testing.expect(@typeInfo(binding_types.EnumDescriptor).@"struct".layout == .@"extern");
    try testing.expect(@typeInfo(binding_types.CallbackDescriptor).@"struct".layout == .@"extern");
}
