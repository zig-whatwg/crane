//! The engine protocol's ECMAScript value operations (design section 4.5),
//! as V8 implements them: Get, Set, DefinePropertyOrThrow, HasProperty,
//! Type, SameValue, and Infra "parse JSON bytes to a JavaScript value" and
//! "serialize a JavaScript value to JSON bytes".
//!
//! Each enters the realm it is given. What script throws (a getter, a
//! setter, a proxy trap, JSON.parse) is left pending and comes back as
//! ExceptionPending, so a binding lets it propagate; where the spec says
//! "throw a TypeError" and nothing has been thrown, the operation returns
//! TypeError for the caller to throw.

const std = @import("std");
const engine = @import("engine");

const ffi = @import("ffi.zig");
const support = @import("protocol_support.zig");
const realm_entry = @import("realm_entry.zig");

const Context = engine.Context;
const JSValue = engine.JSValue;
const Owned = engine.Owned;
const Error = engine.Error;
const Entered = support.Entered;

/// `value` as an Object of the entered realm - a platform object as its
/// wrapper - or TypeError: the ECMAScript operations here take an Object.
/// OWNED.
fn objectOf(entered: Entered, value: JSValue) Error!*ffi.Value {
    switch (value) {
        .handle, .instance => {},
        else => return error.TypeError,
    }
    const object = try support.ownGlobal(entered, value);
    if (!ffi.v8_Value_IsObject(object)) {
        ffi.v8_Global_Dispose(object);
        return error.TypeError;
    }
    return object;
}

/// ECMAScript Get(O, P).
pub fn getProperty(realm: Context, object: JSValue, property: []const u8) Error!Owned {
    const entered = try support.enter(realm);
    defer entered.leave();
    const target = try objectOf(entered, object);
    defer ffi.v8_Global_Dispose(target);
    // 1. Return ? O.[[Get]](P, O).
    return support.owned(try support.get(entered, target, property));
}

/// ECMAScript Set(O, P, V, true).
///
/// Deviation: V8's embedder Set is the sloppy one - a [[Set]] that returns
/// false without throwing (a non-writable data property, a setter-less
/// accessor) reports success - so step 2's TypeError is not thrown.
pub fn setProperty(realm: Context, object: JSValue, property: []const u8, value: JSValue) Error!void {
    const entered = try support.enter(realm);
    defer entered.leave();
    const target = try objectOf(entered, object);
    defer ffi.v8_Global_Dispose(target);
    const key = try support.newString(entered.isolate, property);
    defer ffi.v8_String_Dispose(key);
    const new_value = try support.ownGlobal(entered, value);
    defer ffi.v8_Global_Dispose(new_value);

    // 1. Let success be ? O.[[Set]](P, V, O).
    var body: struct {
        object: *ffi.Value,
        context: *ffi.Context,
        key: *ffi.Value,
        value: *ffi.Value,
        success: bool = false,
        pub fn run(self: *@This()) void {
            self.success = ffi.v8_Object_Set(@ptrCast(self.object), self.context, self.key, self.value);
        }
    } = .{ .object = target, .context = entered.context(), .key = @ptrCast(key), .value = new_value };
    var thrown: ?*ffi.Value = null;
    if (support.catching(entered.isolate, &body, &thrown)) return support.rethrow(entered.isolate, thrown);
    // 2. If success is false and Throw is true, throw a TypeError exception.
    if (!body.success) return error.TypeError;
    // 3. Return unused.
}

/// ECMAScript DefinePropertyOrThrow(O, P, { [[Value]]: V, [[Writable]],
/// [[Enumerable]], [[Configurable]] }).
pub fn defineOwnProperty(realm: Context, object: JSValue, property: []const u8, value: JSValue, attributes: engine.PropertyAttributes) Error!void {
    const entered = try support.enter(realm);
    defer entered.leave();
    const target = try objectOf(entered, object);
    defer ffi.v8_Global_Dispose(target);
    const key = try support.newString(entered.isolate, property);
    defer ffi.v8_String_Dispose(key);
    const new_value = try support.ownGlobal(entered, value);
    defer ffi.v8_Global_Dispose(new_value);

    // 1. Let success be ? O.[[DefineOwnProperty]](P, desc).
    var body: struct {
        object: *ffi.Value,
        context: *ffi.Context,
        key: *ffi.Value,
        value: *ffi.Value,
        attributes: engine.PropertyAttributes,
        success: bool = false,
        pub fn run(self: *@This()) void {
            self.success = ffi.v8_Object_DefineProperty(@ptrCast(self.object), self.context, self.key, self.value, self.attributes.writable, self.attributes.enumerable, self.attributes.configurable);
        }
    } = .{ .object = target, .context = entered.context(), .key = @ptrCast(key), .value = new_value, .attributes = attributes };
    var thrown: ?*ffi.Value = null;
    if (support.catching(entered.isolate, &body, &thrown)) return support.rethrow(entered.isolate, thrown);
    // 2. If success is false, throw a TypeError exception.
    if (!body.success) return error.TypeError;
    // 3. Return unused.
}

/// ECMAScript HasProperty(O, P).
pub fn hasProperty(realm: Context, object: JSValue, property: []const u8) Error!bool {
    const entered = try support.enter(realm);
    defer entered.leave();
    const target = try objectOf(entered, object);
    defer ffi.v8_Global_Dispose(target);
    // The FFI takes the key NUL-terminated.
    const key = realm.allocator.dupeZ(u8, property) catch return error.OutOfMemory;
    defer realm.allocator.free(key);

    // 1. Return ? O.[[HasProperty]](P).
    var body: struct {
        object: *ffi.Value,
        context: *ffi.Context,
        key: [*:0]const u8,
        found: bool = false,
        pub fn run(self: *@This()) void {
            self.found = ffi.v8_Object_Has(self.context, @ptrCast(self.object), self.key);
        }
    } = .{ .object = target, .context = entered.context(), .key = key.ptr };
    var thrown: ?*ffi.Value = null;
    if (support.catching(entered.isolate, &body, &thrown)) return support.rethrow(entered.isolate, thrown);
    return body.found;
}

/// ECMAScript Type(V). A value that is no handle is read from its IDL arm; a
/// handle is asked in `realm`'s agent (undefined when it cannot be entered).
pub fn typeOf(realm: Context, value: JSValue) engine.ValueType {
    return switch (value) {
        .undefined => .undefined,
        .null => .null,
        .boolean => .boolean,
        .number => .number,
        .string => .string,
        .instance => .object,
        .handle => |h| blk: {
            const entered = support.enter(realm) catch break :blk .undefined;
            defer entered.leave();
            break :blk support.typeOfValue(@ptrCast(@alignCast(h.ptr)));
        },
    };
}

/// ECMAScript ToBoolean (7.1.2). A primitive by its IDL arm; an engine
/// value by V8's own ToBoolean, which also answers [[IsHTMLDDA]]
/// (`document.all`) false. Runs no script, so needs no context - only the
/// realm's agent.
pub fn toBoolean(realm: Context, value: JSValue) bool {
    return switch (value) {
        // 1. If argument is a Boolean, return argument.
        .boolean => |b| b,
        // 2. If argument is one of undefined, null, +0, -0, NaN, 0, or the
        // empty String, return false.
        .undefined, .null => false,
        .number => |n| !(n == 0 or std.math.isNan(n)),
        .string => |text| text.data.len != 0,
        // 4. Return true (an Object that is not [[IsHTMLDDA]]).
        .instance => true,
        .handle => |h| blk: {
            const isolate = realm_entry.agentOf(realm) orelse break :blk true;
            const entered_isolate = ffi.v8_Isolate_GetCurrent() != isolate;
            if (entered_isolate) ffi.v8_Isolate_Enter(isolate);
            defer if (entered_isolate) ffi.v8_Isolate_Exit(isolate);
            break :blk ffi.v8_Value_BooleanValue(@ptrCast(@alignCast(h.ptr)), isolate);
        },
    };
}

/// ECMAScript Number::sameValue(x, y).
fn numberSameValue(x: f64, y: f64) bool {
    // 1. If x is NaN and y is NaN, return true.
    if (std.math.isNan(x) and std.math.isNan(y)) return true;
    // 2. If x is +0 and y is -0, return false.
    // 3. If x is -0 and y is +0, return false.
    if (x == 0 and y == 0) return std.math.signbit(x) == std.math.signbit(y);
    // 4. If x is y, return true.
    // 5. Return false.
    return x == y;
}

/// ECMAScript SameValue(x, y), in `realm`'s agent (false when it cannot be
/// entered and a handle has to be read).
pub fn sameValue(realm: Context, a: JSValue, b: JSValue) bool {
    // Two numbers the binding already has: no engine needed.
    if (a == .number and b == .number) return numberSameValue(a.number, b.number);
    const entered = support.enter(realm) catch return false;
    defer entered.leave();
    const x = support.ownGlobal(entered, a) catch return false;
    defer ffi.v8_Global_Dispose(x);
    const y = support.ownGlobal(entered, b) catch return false;
    defer ffi.v8_Global_Dispose(y);
    // 1. If SameType(x, y) is false, return false.
    const x_type = support.typeOfValue(x);
    if (x_type != support.typeOfValue(y)) return false;
    // 2. If x is a Number, then return Number::sameValue(x, y).
    if (x_type == .number) return numberSameValue(ffi.v8_Value_NumberValue(x, entered.context()), ffi.v8_Value_NumberValue(y, entered.context()));
    // 3. Return SameValueNonNumber(x, y): for one type and no Number,
    //    IsStrictlyEqual is the same test (BigInts and Strings by value,
    //    everything else by identity).
    return ffi.v8_Value_StrictEquals(x, y);
}

/// Infra "parse JSON bytes to a JavaScript value".
pub fn parseJsonToValue(realm: Context, bytes: []const u8) Error!Owned {
    const entered = try support.enter(realm);
    defer entered.leave();
    // 1. Let string be the result of running UTF-8 decode on bytes: a
    //    leading BOM is not part of the string; V8's UTF-8 decoding replaces
    //    every error with U+FFFD, as the decoder does.
    const text = if (std.mem.startsWith(u8, bytes, "\xEF\xBB\xBF")) bytes[3..] else bytes;
    if (text.len > std.math.maxInt(c_int)) return error.OperationFailed;
    // 2. Return ? Call(%JSON.parse%, undefined, « string »). V8's JSON::Parse
    //    is the intrinsic, whatever script did to the global JSON; a
    //    SyntaxError is left pending. The result is a Local in the entered
    //    scope, held past it as a Global.
    const local = ffi.v8_JSON_Parse_FromBuffer(entered.context(), text.ptr, @intCast(text.len)) orelse
        return error.ExceptionPending;
    return support.owned(ffi.v8_Value_ToGlobal(entered.isolate, @ptrCast(local)) orelse return error.OperationFailed);
}

/// Infra "serialize a JavaScript value to JSON bytes". OWNED (`allocator`).
pub fn serializeJsonToBytes(realm: Context, value: JSValue, allocator: std.mem.Allocator) Error![]u8 {
    const entered = try support.enter(realm);
    defer entered.leave();
    const object = try support.ownGlobal(entered, value);
    defer ffi.v8_Global_Dispose(object);
    // 1. Let string be the result of serializing a JavaScript value to a
    //    JSON string given value:
    //    1. Let result be ? Call(%JSON.stringify%, undefined, « value »):
    //       what it throws is left pending.
    var no_representation = false;
    const string = ffi.v8_JSON_StringifyValue(entered.context(), object, &no_representation) orelse
        //  2. If result is undefined, then throw a TypeError.
        return if (no_representation) error.TypeError else error.ExceptionPending;
    defer ffi.v8_Global_Dispose(string);
    // 2. Return the result of running UTF-8 encode on string. JSON.stringify
    //    escapes a lone surrogate (ES2019's well-formed JSON.stringify), so
    //    the string is scalar values and V8's UTF-8 is that encoding.
    const length = ffi.v8_String_Utf8Length(@ptrCast(string));
    if (length < 0) return error.OperationFailed;
    const bytes = try allocator.alloc(u8, @intCast(length));
    errdefer allocator.free(bytes);
    if (bytes.len > 0 and ffi.v8_String_WriteUtf8(@ptrCast(string), bytes.ptr, length) != length) return error.OperationFailed;
    return bytes;
}

/// WebIDL "create a simple exception" of type SyntaxError: Construct(`realm`'s
/// intrinsic %SyntaxError%, « `message` »). OWNED.
pub fn createSyntaxError(realm: Context, message: []const u8) Error!Owned {
    const entered = try support.enter(realm);
    defer entered.leave();
    const text = try support.newString(entered.isolate, message);
    defer ffi.v8_String_Dispose(text);
    return support.owned(ffi.v8_Exception_SyntaxErrorInContext(entered.context(), text) orelse return error.OperationFailed);
}
