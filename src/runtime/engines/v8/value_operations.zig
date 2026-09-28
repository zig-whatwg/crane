//! Engine operations on values that cross the seam and are held there:
//! retainValue, throwValue and createFrozenArrayOfPlatformObjects, as V8
//! implements them (AGENTS.md, "The engine boundary"). The WebIDL conversions
//! of arguments an impl takes unconverted are webidl_conversions.zig.
//!
//! Code outside the adapter holds a script value as a `runtime.JSValue`. When
//! it must outlive the call that handed it over - an AbortSignal's reason, a
//! timer's callback - the engine gives it a handle of its own (`retainValue`),
//! released with the Engine table's `releaseValue`. Every function here enters
//! the realm it is given, so a caller needs no scope of its own.

const std = @import("std");
const runtime = @import("runtime");
const EngineError = runtime.EngineError;

const ffi = @import("ffi.zig");
const engine = @import("engine.zig");
const conversions = @import("conversions.zig");

/// A handle of our own for `value`, entered in `isolate`/`context`: always a
/// new Global the caller disposes. Borrowed inputs are copied, never taken.
pub fn ownHandle(isolate: *ffi.Isolate, context: *ffi.Context, value: runtime.JSValue) EngineError!*ffi.Value {
    return switch (value) {
        // Copied into a second, independently owned Global.
        .handle => ffi.v8_Global_Clone(handleOf(value).?) orelse EngineError.OperationFailed,
        // The wrapper cache owns the wrapper; the caller gets its own handle.
        .instance => |instance| blk: {
            const wrapper = conversions.instanceToV8(isolate, instance);
            break :blk ffi.v8_Global_Clone(wrapper) orelse EngineError.OperationFailed;
        },
        // A string is WTF-8 (conversions.fromV8Value writes a lone
        // surrogate as its three-byte form): one holding a surrogate code
        // point is made from its UTF-16, which keeps it; UTF-8 would make
        // each of its bytes a U+FFFD.
        .string => |text| if (hasSurrogateCodePoint(text.data))
            stringFromWtf8(isolate, text.data)
        else
            conversions.toV8Value(runtime.JSValue, isolate, context, value) catch EngineError.OperationFailed,
        // Every other kind is made here, in the realm: a new Global.
        else => conversions.toV8Value(runtime.JSValue, isolate, context, value) catch EngineError.OperationFailed,
    };
}

/// Whether `bytes` holds a surrogate code point in WTF-8's three-byte form,
/// ED A0..BF xx: what v8_String_NewFromUtf8 cannot keep.
fn hasSurrogateCodePoint(bytes: []const u8) bool {
    var from: usize = 0;
    while (std.mem.indexOfScalarPos(u8, bytes, from, 0xED)) |at| {
        if (at + 1 < bytes.len and bytes[at + 1] >= 0xA0 and bytes[at + 1] <= 0xBF) return true;
        from = at + 1;
    }
    return false;
}

/// A new V8 string of the code units `bytes` encodes as WTF-8. OWNED.
fn stringFromWtf8(isolate: *ffi.Isolate, bytes: []const u8) EngineError!*ffi.Value {
    var fallback = std.heap.stackFallback(2048, std.heap.c_allocator);
    const allocator = fallback.get();
    // Never more code units than bytes: each decodes from at least one.
    const units = allocator.alloc(u16, bytes.len) catch return EngineError.OutOfMemory;
    defer allocator.free(units);
    const count = wtf8ToUtf16(bytes, units);
    if (count > std.math.maxInt(c_int)) return EngineError.OperationFailed;
    return ffi.v8_Value_StringFromTwoByte(isolate, units.ptr, @intCast(count)) orelse EngineError.OperationFailed;
}

/// WTF-8 to UTF-16, into `units` (at least `bytes.len` long); the count
/// written. The WHATWG Encoding standard's UTF-8 decoder with one change:
/// after ED the upper boundary stays BF rather than 9F, so a surrogate code
/// point decodes to its own code unit. Anything else ill-formed becomes
/// U+FFFD exactly as UTF-8 decode makes it.
fn wtf8ToUtf16(bytes: []const u8, units: []u16) usize {
    var out: usize = 0;
    var code_point: u21 = 0;
    var needed: u2 = 0;
    var seen: u2 = 0;
    var lower: u8 = 0x80;
    var upper: u8 = 0xBF;
    var i: usize = 0;
    while (i < bytes.len) {
        const byte = bytes[i];
        if (needed == 0) {
            i += 1;
            switch (byte) {
                0x00...0x7F => {
                    units[out] = byte;
                    out += 1;
                },
                0xC2...0xDF => {
                    needed = 1;
                    code_point = byte & 0x1F;
                },
                0xE0...0xEF => {
                    // UTF-8 also sets upper to 9F after ED; WTF-8 does not.
                    if (byte == 0xE0) lower = 0xA0;
                    needed = 2;
                    code_point = byte & 0x0F;
                },
                0xF0...0xF4 => {
                    if (byte == 0xF0) lower = 0x90;
                    if (byte == 0xF4) upper = 0x8F;
                    needed = 3;
                    code_point = byte & 0x07;
                },
                else => {
                    units[out] = 0xFFFD;
                    out += 1;
                },
            }
            continue;
        }
        if (byte < lower or byte > upper) {
            // An error; the byte is looked at again as the start of what
            // follows.
            needed = 0;
            seen = 0;
            lower = 0x80;
            upper = 0xBF;
            units[out] = 0xFFFD;
            out += 1;
            continue;
        }
        i += 1;
        lower = 0x80;
        upper = 0xBF;
        code_point = (code_point << 6) | (byte & 0x3F);
        seen += 1;
        if (seen != needed) continue;
        if (code_point < 0x10000) {
            units[out] = @intCast(code_point);
            out += 1;
        } else {
            const offset = code_point - 0x10000;
            units[out] = @intCast(0xD800 + (offset >> 10));
            units[out + 1] = @intCast(0xDC00 + (offset & 0x3FF));
            out += 2;
        }
        needed = 0;
        seen = 0;
    }
    // Input that ends inside a sequence.
    if (needed != 0) {
        units[out] = 0xFFFD;
        out += 1;
    }
    return out;
}

/// The V8 value a `.handle` JSValue holds, BORROWED; null for any other kind.
///
/// The pointer is a Global<Value>* whichever way `handle_scope` is tagged.
/// `.local` says who owns it and how long it lives - the binding's own
/// handle for an argument, valid for the call (conversions.fromV8Value) -
/// not that it is a Local's slot: every value this FFI hands out is a
/// Global. Reading a `.local` one as a Local (v8_Value_ToGlobal,
/// v8_Value_IsFunction_Local) reinterprets the Global's address as the
/// value, which is how AbortSignal.abort({...}).throwIfAborted() came to
/// throw a number.
pub fn handleOf(value: runtime.JSValue) ?*ffi.Value {
    return switch (value) {
        .handle => |h| @ptrCast(@alignCast(h.ptr)),
        else => null,
    };
}

/// Engine table `retainValue`: OWNED `.handle` for any `value`.
pub fn retainValue(realm: runtime.Context, value: runtime.JSValue) EngineError!runtime.JSValue {
    const entered = try engine.enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    const held = try ownHandle(entered.isolate, entered.scope.context, value);
    return .{ .handle = .{ .ptr = @ptrCast(held), .needs_disposal = true, .handle_scope = .global } };
}

/// Engine table `throwValue`: `value` (borrowed) becomes the pending
/// exception of `realm`'s agent.
pub fn throwValue(realm: runtime.Context, value: runtime.JSValue) EngineError!void {
    const entered = try engine.enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    // ThrowException takes the value, not the handle: ours goes after.
    const thrown = try ownHandle(entered.isolate, entered.scope.context, value);
    defer ffi.v8_Global_Dispose(thrown);
    ffi.v8_Isolate_ThrowException(entered.isolate, thrown);
}

/// Engine table `createFrozenArrayOfPlatformObjects`: WebIDL "create a
/// frozen array" from a list of platform objects - each item its wrapper in
/// `realm`, the array made in `realm` and frozen. OWNED `.handle`.
pub fn createFrozenArrayOfPlatformObjects(realm: runtime.Context, instances: []const *runtime.Instance) EngineError!runtime.JSValue {
    const entered = try engine.enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    const isolate = entered.isolate;
    const context = entered.scope.context;
    // 1. Let array be the result of converting the list of values to an
    // ECMAScript value - an Array of `realm`.
    const array = ffi.v8_Array_NewInContext(context, @intCast(instances.len)) orelse return EngineError.OperationFailed;
    errdefer ffi.v8_Array_Dispose(array);
    for (instances, 0..) |instance, i| {
        // Borrowed: the wrapper cache owns the wrapper; Set keeps its own.
        const wrapper = conversions.instanceToV8(isolate, instance);
        if (!ffi.v8_Array_Set(array, context, @intCast(i), wrapper)) return EngineError.OperationFailed;
    }
    // 2. Perform ! SetIntegrityLevel(array, "frozen").
    if (!ffi.v8_Object_Freeze(@ptrCast(array), context)) return EngineError.OperationFailed;
    // 3. Return array.
    return .{ .handle = .{ .ptr = @ptrCast(array), .needs_disposal = true, .handle_scope = .global } };
}
