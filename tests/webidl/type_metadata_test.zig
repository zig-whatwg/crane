//! Tests for WebIDL Type Metadata System

const std = @import("std");
const testing = std.testing;
const webidl = @import("webidl");

// Test primitive type metadata
test "typeMetadata - boolean" {
    const meta = comptime webidl.typeMetadata("boolean");
    try testing.expectEqual(bool, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.primitive, meta.kind);
    try testing.expectEqualStrings("boolean", meta.js_type);
    try testing.expect(meta.union_members == null);
    try testing.expect(meta.inner_types == null);
    try testing.expect(meta.conversion != null);
}

test "typeMetadata - long" {
    const meta = comptime webidl.typeMetadata("long");
    try testing.expectEqual(i32, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.primitive, meta.kind);
    try testing.expectEqualStrings("number", meta.js_type);
    try testing.expect(meta.conversion != null);
    try testing.expect(meta.conversion.?.from_js != null);
}

test "typeMetadata - unsigned long" {
    const meta = comptime webidl.typeMetadata("unsigned long");
    try testing.expectEqual(u32, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.primitive, meta.kind);
    try testing.expectEqualStrings("number", meta.js_type);
}

test "typeMetadata - double" {
    const meta = comptime webidl.typeMetadata("double");
    try testing.expectEqual(f64, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.primitive, meta.kind);
    try testing.expectEqualStrings("number", meta.js_type);
}

test "typeMetadata - float" {
    const meta = comptime webidl.typeMetadata("float");
    try testing.expectEqual(f32, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.primitive, meta.kind);
    try testing.expectEqualStrings("number", meta.js_type);
}

test "typeMetadata - bigint" {
    const meta = comptime webidl.typeMetadata("bigint");
    try testing.expectEqual(webidl.BigInt, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.bigint, meta.kind);
    try testing.expectEqualStrings("bigint", meta.js_type);
    try testing.expect(meta.conversion != null);
    try testing.expect(meta.conversion.?.from_js_sig.?.needs_allocator);
}

// Test string type metadata
test "typeMetadata - DOMString" {
    const meta = comptime webidl.typeMetadata("DOMString");
    try testing.expectEqual(webidl.DOMString, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.string, meta.kind);
    try testing.expectEqualStrings("string", meta.js_type);
    try testing.expect(meta.conversion != null);
    try testing.expect(meta.conversion.?.from_js_sig.?.needs_allocator);
}

test "typeMetadata - ByteString" {
    const meta = comptime webidl.typeMetadata("ByteString");
    try testing.expectEqual(webidl.ByteString, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.string, meta.kind);
    try testing.expectEqualStrings("string", meta.js_type);
}

test "typeMetadata - USVString" {
    const meta = comptime webidl.typeMetadata("USVString");
    try testing.expectEqual(webidl.USVString, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.string, meta.kind);
    try testing.expectEqualStrings("string", meta.js_type);
}

// Test special type metadata
test "typeMetadata - any" {
    const meta = comptime webidl.typeMetadata("any");
    try testing.expectEqual(webidl.JSValue, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.any, meta.kind);
    try testing.expectEqualStrings("any", meta.js_type);
    try testing.expect(meta.conversion == null);
}

test "typeMetadata - object" {
    const meta = comptime webidl.typeMetadata("object");
    try testing.expectEqual(*anyopaque, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.object, meta.kind);
    try testing.expectEqualStrings("object", meta.js_type);
}

test "typeMetadata - symbol" {
    const meta = comptime webidl.typeMetadata("symbol");
    try testing.expectEqual(*anyopaque, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.symbol, meta.kind);
    try testing.expectEqualStrings("symbol", meta.js_type);
}

// Test buffer type metadata
test "typeMetadata - ArrayBuffer" {
    const meta = comptime webidl.typeMetadata("ArrayBuffer");
    try testing.expectEqual(webidl.ArrayBuffer, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.buffer, meta.kind);
    try testing.expectEqualStrings("object", meta.js_type);
}

test "typeMetadata - SharedArrayBuffer" {
    const meta = comptime webidl.typeMetadata("SharedArrayBuffer");
    try testing.expectEqual(webidl.SharedArrayBuffer, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.buffer, meta.kind);
    try testing.expectEqualStrings("object", meta.js_type);
}

test "typeMetadata - DataView" {
    const meta = comptime webidl.typeMetadata("DataView");
    try testing.expectEqual(webidl.DataView, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.buffer_view, meta.kind);
    try testing.expectEqualStrings("object", meta.js_type);
}

test "typeMetadata - Uint8Array" {
    const meta = comptime webidl.typeMetadata("Uint8Array");
    try testing.expectEqual(webidl.TypedArray(u8), meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.typed_array, meta.kind);
    try testing.expectEqualStrings("object", meta.js_type);
}

test "typeMetadata - Int32Array" {
    const meta = comptime webidl.typeMetadata("Int32Array");
    try testing.expectEqual(webidl.TypedArray(i32), meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.typed_array, meta.kind);
}

test "typeMetadata - Float64Array" {
    const meta = comptime webidl.typeMetadata("Float64Array");
    try testing.expectEqual(webidl.TypedArray(f64), meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.typed_array, meta.kind);
}

// Test union type metadata
test "typeMetadata - ArrayBufferView" {
    const meta = comptime webidl.typeMetadata("ArrayBufferView");
    try testing.expectEqual(webidl.ArrayBufferView, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.union_type, meta.kind);
    try testing.expectEqualStrings("object", meta.js_type);
    try testing.expect(meta.union_members != null);
    try testing.expectEqual(@as(usize, 12), meta.union_members.?.len);
}

test "typeMetadata - BufferSource" {
    const meta = comptime webidl.typeMetadata("BufferSource");
    try testing.expectEqual(webidl.BufferSource, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.union_type, meta.kind);
    try testing.expect(meta.union_members != null);
    try testing.expectEqual(@as(usize, 2), meta.union_members.?.len);
    try testing.expectEqualStrings("ArrayBufferView", meta.union_members.?[0]);
    try testing.expectEqualStrings("ArrayBuffer", meta.union_members.?[1]);
}

test "typeMetadata - AllowSharedBufferSource" {
    const meta = comptime webidl.typeMetadata("AllowSharedBufferSource");
    try testing.expectEqual(webidl.AllowSharedBufferSource, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.union_type, meta.kind);
    try testing.expect(meta.union_members != null);
    try testing.expectEqual(@as(usize, 3), meta.union_members.?.len);
}

// Test generic container metadata
test "typeMetadata - sequence" {
    const meta = comptime webidl.typeMetadata("sequence");
    try testing.expectEqual(type, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.sequence, meta.kind);
    try testing.expectEqualStrings("object", meta.js_type);
    try testing.expect(meta.inner_types != null);
    try testing.expectEqual(@as(usize, 1), meta.inner_types.?.len);
    try testing.expectEqualStrings("T", meta.inner_types.?[0]);
}

test "typeMetadata - record" {
    const meta = comptime webidl.typeMetadata("record");
    try testing.expectEqual(type, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.record, meta.kind);
    try testing.expect(meta.inner_types != null);
    try testing.expectEqual(@as(usize, 2), meta.inner_types.?.len);
    try testing.expectEqualStrings("K", meta.inner_types.?[0]);
    try testing.expectEqualStrings("V", meta.inner_types.?[1]);
}

test "typeMetadata - FrozenArray" {
    const meta = comptime webidl.typeMetadata("FrozenArray");
    try testing.expectEqual(type, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.frozen_array, meta.kind);
    try testing.expect(meta.inner_types != null);
    try testing.expectEqual(@as(usize, 1), meta.inner_types.?.len);
    try testing.expectEqualStrings("T", meta.inner_types.?[0]);
}

test "typeMetadata - ObservableArray" {
    const meta = comptime webidl.typeMetadata("ObservableArray");
    try testing.expectEqual(type, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.observable_array, meta.kind);
    try testing.expect(meta.inner_types != null);
}

test "typeMetadata - Promise" {
    const meta = comptime webidl.typeMetadata("Promise");
    try testing.expectEqual(type, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.promise, meta.kind);
    try testing.expect(meta.inner_types != null);
    try testing.expectEqualStrings("T", meta.inner_types.?[0]);
}

test "typeMetadata - nullable" {
    const meta = comptime webidl.typeMetadata("nullable");
    try testing.expectEqual(type, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.nullable, meta.kind);
    try testing.expect(meta.inner_types != null);
    try testing.expectEqualStrings("T", meta.inner_types.?[0]);
}

// Test error type metadata
test "typeMetadata - DOMException" {
    const meta = comptime webidl.typeMetadata("DOMException");
    try testing.expectEqual(webidl.DOMException, meta.zig_type);
    try testing.expectEqual(webidl.TypeKind.interface, meta.kind);
    try testing.expectEqualStrings("object", meta.js_type);
}

// Test conversion function metadata
test "typeMetadata - conversion function signature for long" {
    const meta = comptime webidl.typeMetadata("long");
    try testing.expect(meta.conversion != null);
    const conv = meta.conversion.?;
    try testing.expect(conv.from_js != null);
    try testing.expect(conv.from_js_sig != null);

    const sig = conv.from_js_sig.?;
    try testing.expect(!sig.needs_allocator);
    try testing.expect(!sig.needs_type_param);
    try testing.expect(!sig.needs_extended_attrs);
    try testing.expectEqual(@as(usize, 1), sig.param_types.len);
    try testing.expectEqual(i32, sig.return_type);
}

test "typeMetadata - conversion function signature for DOMString" {
    const meta = comptime webidl.typeMetadata("DOMString");
    try testing.expect(meta.conversion != null);
    const conv = meta.conversion.?;
    try testing.expect(conv.from_js_sig != null);

    const sig = conv.from_js_sig.?;
    try testing.expect(sig.needs_allocator);
    try testing.expect(!sig.needs_type_param);
    try testing.expectEqual(@as(usize, 2), sig.param_types.len);
    try testing.expectEqual(webidl.DOMString, sig.return_type);
}

test "typeMetadata - conversion function signature for bigint" {
    const meta = comptime webidl.typeMetadata("bigint");
    try testing.expect(meta.conversion != null);
    const conv = meta.conversion.?;
    try testing.expect(conv.from_js_sig != null);

    const sig = conv.from_js_sig.?;
    try testing.expect(sig.needs_allocator);
    try testing.expect(!sig.needs_type_param);
    try testing.expectEqual(webidl.BigInt, sig.return_type);
}

// Test type alias exports
test "type aliases - primitives exported" {
    try testing.expectEqual(i32, webidl.long);
    try testing.expectEqual(u32, webidl.@"unsigned long");
    try testing.expectEqual(i64, webidl.@"long long");
    try testing.expectEqual(f64, webidl.double);
    try testing.expectEqual(f32, webidl.float);
    try testing.expectEqual(bool, webidl.boolean);
    try testing.expectEqual(i8, webidl.byte);
    try testing.expectEqual(u8, webidl.octet);
}

test "type aliases - string types exported" {
    try testing.expectEqual(webidl.DOMString, webidl.DOMString);
    try testing.expectEqual(webidl.ByteString, webidl.ByteString);
    try testing.expectEqual(webidl.USVString, webidl.USVString);
}

test "type aliases - special types exported" {
    try testing.expectEqual(webidl.JSValue, webidl.any);
    try testing.expectEqual(*anyopaque, webidl.object);
    try testing.expectEqual(*anyopaque, webidl.symbol);
}
