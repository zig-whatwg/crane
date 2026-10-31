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
const value_operations = @import("value_operations.zig");
const protocol_agents = @import("protocol_agents.zig");

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
    const key = realm.allocator.dupeSentinel(u8, property, 0) catch return error.OutOfMemory;
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

/// ECMAScript HasOwnProperty(O, P) (7.3.12). A throw is left pending.
pub fn hasOwnProperty(realm: Context, object: JSValue, property: []const u8) Error!bool {
    const entered = try support.enter(realm);
    defer entered.leave();
    const target = try objectOf(entered, object);
    defer ffi.v8_Global_Dispose(target);
    const key = try support.newString(entered.isolate, property);
    defer ffi.v8_String_Dispose(key);
    // 1. Let desc be ? O.[[GetOwnProperty]](P).
    // 2-3. Return desc is not undefined.
    return switch (ffi.v8_Object_HasOwnPropertyOrThrow(@ptrCast(target), entered.context(), @ptrCast(key))) {
        1 => true,
        0 => false,
        else => error.ExceptionPending,
    };
}

/// thisTimeValue(value), without its TypeError: null when no [[DateValue]].
pub fn thisTimeValue(realm: Context, value: JSValue) ?f64 {
    const handle = support.handleOf(value) orelse return null;
    const entered = support.enter(realm) catch return null;
    defer entered.leave();
    // 1. If value is an Object and value has a [[DateValue]] internal slot,
    //    return value.[[DateValue]]. (V8's IsDate is that slot.)
    if (!ffi.v8_Value_IsDate(handle)) return null;
    return ffi.v8_Date_ValueOf(handle);
}

/// An Array exotic object: V8's IsArray is JSArray alone (a Proxy is not
/// one), which is the definition, where ECMAScript IsArray looks through
/// proxies.
pub fn isArrayExoticObject(realm: Context, value: JSValue) bool {
    const handle = support.handleOf(value) orelse return false;
    const entered = support.enter(realm) catch return false;
    defer entered.leave();
    return ffi.v8_Value_IsArray(handle);
}

/// A new Date of `realm`: Date::New applies TimeClip. OWNED.
pub fn createDate(realm: Context, time_value: f64) Error!Owned {
    const entered = try support.enter(realm);
    defer entered.leave();
    return support.owned(ffi.v8_Date_New(entered.isolate, entered.context(), time_value) orelse return error.OperationFailed);
}

/// ECMAScript JSON.parse "in the context of a new global object" (WebCrypto
/// "parse a JWK" step 4). OWNED.
///
/// The new global is a throwaway V8 context - ECMAScript's intrinsics, no
/// platform objects - made in `realm`'s isolate and given `realm`'s security
/// token. Its handle goes before this returns: the context lives exactly as
/// long as something refers to its objects (the result's prototypes, its
/// Object.prototype), and a dropped result lets the collector take it. A
/// SyntaxError is caught under a TryCatch and thrown again as `realm`'s own
/// SyntaxError, with the new global's message, so script sees the caller's
/// SyntaxError: ExceptionPending.
pub fn parseJsonInNewGlobal(realm: Context, bytes: []const u8) Error!Owned {
    const entered = try support.enter(realm);
    defer entered.leave();
    // 1-3. UTF-8 decode, a leading BOM dropped (as parseJsonToValue): V8's
    //      decoding replaces every error with U+FFFD.
    const text = if (std.mem.startsWith(u8, bytes, "\xEF\xBB\xBF")) bytes[3..] else bytes;
    if (text.len > std.math.maxInt(c_int)) return error.OperationFailed;
    // A new global object: v8_Context_New makes a plain global in a snapshot
    //    agent too - a page's (tests/v8/new_global_snapshot_test.zig).
    const fresh = ffi.v8_Context_New(entered.isolate) orelse return error.OperationFailed;
    defer ffi.v8_Context_Dispose(fresh);
    if (ffi.v8_Context_GetSecurityToken(entered.context())) |token| {
        defer ffi.v8_Value_Dispose(token);
        ffi.v8_Context_SetSecurityToken(fresh, token);
    }
    // 4. JSON.parse, the new global's intrinsic, with the new global entered:
    //    v8_JSON_Parse_FromBuffer parses in the CURRENT context.
    const Parse = struct {
        isolate: *ffi.Isolate,
        context: *ffi.Context,
        text: []const u8,
        result: ?*ffi.Value = null,

        pub fn run(self: *@This()) void {
            ffi.v8_Context_Enter(self.context);
            defer ffi.v8_Context_Exit(self.context);
            // A Local in the TryCatch's scope: held past it as a Global.
            const local = ffi.v8_JSON_Parse_FromBuffer(self.context, self.text.ptr, @intCast(self.text.len)) orelse return;
            self.result = ffi.v8_Value_ToGlobal(self.isolate, @ptrCast(local));
        }
    };
    var parse = Parse{ .isolate = entered.isolate, .context = fresh, .text = text };
    var thrown: ?*ffi.Value = null;
    if (support.catching(entered.isolate, &parse, &thrown)) {
        if (parse.result) |result| ffi.v8_Global_Dispose(result);
        return syntaxErrorInCaller(entered, thrown);
    }
    return support.owned(parse.result orelse return error.OperationFailed);
}

/// Throw, in the entered realm, a SyntaxError carrying the message of
/// `thrown` - what a new global's JSON.parse threw - and answer
/// ExceptionPending. Takes `thrown`. A throw that is no SyntaxError's (none
/// is expected of JSON.parse) is thrown as it is.
fn syntaxErrorInCaller(entered: Entered, thrown: ?*ffi.Value) Error {
    const exception = thrown orelse return error.ExceptionPending;
    defer ffi.v8_Global_Dispose(exception);
    const message = messageOf(entered, exception) orelse {
        ffi.v8_Isolate_ThrowException(entered.isolate, exception);
        return error.ExceptionPending;
    };
    defer ffi.v8_String_Dispose(message);
    const own = ffi.v8_Exception_SyntaxErrorInContext(entered.context(), message) orelse return error.OperationFailed;
    return support.rethrow(entered.isolate, own);
}

/// The `message` of an error object, as a string; null for anything else.
/// Read under a TryCatch: nothing pending either way. OWNED.
fn messageOf(entered: Entered, exception: *ffi.Value) ?*ffi.String {
    if (!ffi.v8_Value_IsObject(exception)) return null;
    const Read = struct {
        entered: Entered,
        exception: *ffi.Value,
        message: ?*ffi.String = null,

        pub fn run(self: *@This()) void {
            const value = support.get(self.entered, self.exception, "message") catch return;
            defer ffi.v8_Value_Dispose(value);
            if (!ffi.v8_Value_IsString(value)) return;
            self.message = ffi.v8_Value_ToString(value, self.entered.context());
        }
    };
    var read = Read{ .entered = entered, .exception = exception };
    var thrown: ?*ffi.Value = null;
    if (support.catching(entered.isolate, &read, &thrown)) {
        if (thrown) |t| ffi.v8_Global_Dispose(t);
        if (read.message) |m| ffi.v8_String_Dispose(m);
        return null;
    }
    return read.message;
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

/// HTML 4.10.5.3.6: the compiled pattern regular expression of `pattern`
/// and "check if an input value matches" for `value`. Both regexps are
/// compiled, and the value matched, in the agent's own utility context with
/// its built-in RegExp (v8_wrapper.cpp, v8_MatchesPatternAttribute, says why
/// V8's RegExp::Exec in the page's realm would not do), and a pattern is
/// compiled once per agent and cached (protocol_agents.patternMatcherOf;
/// Blink's ScriptRegexp context and HTMLInputElement's cached ScriptRegexp):
/// nothing the page did to RegExp or RegExp.prototype is reached, no script
/// runs, nothing outlives the agent, and it is a native step - no kAuto
/// microtask checkpoint. A realm with no engine left cannot match:
/// NotSupported, which the caller treats as it does an invalid pattern (no
/// constraint).
pub fn matchesPatternAttribute(realm: Context, pattern: []const u8, value: []const u8) error{ InvalidPattern, NotSupported, OutOfMemory }!bool {
    const entered = support.enter(realm) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.NotSupported,
    };
    defer entered.leave();
    // WTF-8 to UTF-16: never more code units than bytes.
    var fallback_buffer: [1024]u8 = undefined;
    var fallback: std.heap.BufferFirstAllocator = .init(&fallback_buffer, std.heap.c_allocator);
    const allocator = fallback.allocator();
    const units = try allocator.alloc(u16, pattern.len + value.len);
    defer allocator.free(units);
    const pattern_units = units[0..value_operations.wtf8ToUtf16(pattern, units[0..pattern.len])];
    const value_units = units[pattern.len..][0..value_operations.wtf8ToUtf16(value, units[pattern.len..])];
    if (pattern_units.len > std.math.maxInt(c_int) or value_units.len > std.math.maxInt(c_int)) return error.OutOfMemory;
    const matcher = protocol_agents.patternMatcherOf(entered.isolate);
    return switch (ffi.v8_MatchesPatternAttribute(entered.isolate, matcher, pattern_units.ptr, @intCast(pattern_units.len), value_units.ptr, @intCast(value_units.len))) {
        1 => true,
        0 => false,
        -1 => error.InvalidPattern,
        else => error.OutOfMemory,
    };
}

/// `realm`'s agent, entered for the regexp operations until `leave`: they
/// make and match their regexps in the agent's utility context
/// (protocol_agents.patternMatcherOf), so the realm's own context is not
/// entered - a realm retired since (a detached frame's: hasEngine() false)
/// still names its agent, and answers.
const RegExpAgent = struct {
    isolate: *ffi.Isolate,
    entered: bool,
    matcher: ?*ffi.PatternMatcher,

    fn enter(realm: Context) error{NotSupported}!RegExpAgent {
        const isolate = realm_entry.agentOf(realm) orelse return error.NotSupported;
        const entered = ffi.v8_Isolate_GetCurrent() != isolate;
        if (entered) ffi.v8_Isolate_Enter(isolate);
        return .{ .isolate = isolate, .entered = entered, .matcher = protocol_agents.patternMatcherOf(isolate) };
    }

    fn leave(self: RegExpAgent) void {
        if (self.entered) ffi.v8_Isolate_Exit(self.isolate);
    }
};

/// ECMAScript RegExpCreate(pattern, "v" or "vi"), for its completion: in the
/// agent's utility context with its intrinsic %RegExp% (v8_wrapper.cpp,
/// v8_RegExpCreateCheck), the compiled regexp kept in the agent's bounded
/// cache for regExpBuiltinExecCaptures (Blink's ScriptRegexp context; a
/// URLPattern component keeps its ScriptRegexp). Nothing the page can reach
/// is made, no script runs, and it is a native step - no kAuto microtask
/// checkpoint. A terminating agent cannot answer: NotSupported.
pub fn regExpCreateCheck(realm: Context, pattern: []const u8, ignore_case: bool) error{ InvalidPattern, NotSupported, OutOfMemory }!void {
    const agent = try RegExpAgent.enter(realm);
    defer agent.leave();
    // WTF-8 to UTF-16: never more code units than bytes.
    var fallback_buffer: [1024]u8 = undefined;
    var fallback: std.heap.BufferFirstAllocator = .init(&fallback_buffer, std.heap.c_allocator);
    const allocator = fallback.allocator();
    const units = try allocator.alloc(u16, pattern.len);
    defer allocator.free(units);
    const pattern_units = units[0..value_operations.wtf8ToUtf16(pattern, units)];
    if (pattern_units.len > std.math.maxInt(c_int)) return error.OutOfMemory;
    return switch (ffi.v8_RegExpCreateCheck(agent.isolate, agent.matcher, pattern_units.ptr, @intCast(pattern_units.len), ignore_case)) {
        1 => {},
        -1 => error.InvalidPattern,
        -3 => error.NotSupported,
        else => error.OutOfMemory,
    };
}

/// ECMAScript RegExpBuiltinExec(RegExpCreate(pattern, "v" or "vi"), input)
/// with lastIndex 0, in the agent's utility context (v8_wrapper.cpp,
/// v8_RegExpBuiltinExecCaptures, says why RegExp::Exec in the page's realm
/// would not do): null for no match - a match stopped at Blink's backtrack
/// limit included - else the result's elements 0..n, OWNED (`allocator`),
/// null for an undefined group. WTF-8 in and out. A terminating agent
/// matches nothing.
pub fn regExpBuiltinExecCaptures(realm: Context, pattern: []const u8, ignore_case: bool, input: []const u8, allocator: std.mem.Allocator) error{ InvalidPattern, NotSupported, OutOfMemory }!?[]?[]u8 {
    var buffer: ?[*]u8 = null;
    var size: usize = 0;
    {
        const agent = try RegExpAgent.enter(realm);
        defer agent.leave();
        var fallback_buffer: [2048]u8 = undefined;
        var fallback: std.heap.BufferFirstAllocator = .init(&fallback_buffer, std.heap.c_allocator);
        const scratch = fallback.allocator();
        // WTF-8 to UTF-16: never more code units than bytes.
        const units = try scratch.alloc(u16, pattern.len + input.len);
        defer scratch.free(units);
        const pattern_units = units[0..value_operations.wtf8ToUtf16(pattern, units[0..pattern.len])];
        const input_units = units[pattern.len..][0..value_operations.wtf8ToUtf16(input, units[pattern.len..])];
        if (pattern_units.len > std.math.maxInt(c_int) or input_units.len > std.math.maxInt(c_int)) return error.OutOfMemory;
        switch (ffi.v8_RegExpBuiltinExecCaptures(agent.isolate, agent.matcher, pattern_units.ptr, @intCast(pattern_units.len), ignore_case, input_units.ptr, @intCast(input_units.len), &buffer, &size)) {
            1 => {},
            0, -3 => return null,
            -1 => return error.InvalidPattern,
            else => return error.OutOfMemory,
        }
    }
    const bytes = buffer.?[0..size];
    defer std.c.free(bytes.ptr);
    return try readCaptures(bytes, allocator);
}

/// v8_RegExpBuiltinExecCaptures' buffer as owned captures: a u32 count, then
/// per element an i32 length (-1: undefined) and its bytes, unaligned.
fn readCaptures(bytes: []const u8, allocator: std.mem.Allocator) error{OutOfMemory}![]?[]u8 {
    var at: usize = 0;
    const count = std.mem.readInt(u32, bytes[at..][0..4], .native);
    at += 4;
    const captures = try allocator.alloc(?[]u8, count);
    var made: usize = 0;
    errdefer {
        for (captures[0..made]) |capture| if (capture) |value| allocator.free(value);
        allocator.free(captures);
    }
    while (made < count) : (made += 1) {
        const length = std.mem.readInt(i32, bytes[at..][0..4], .native);
        at += 4;
        if (length < 0) {
            captures[made] = null;
            continue;
        }
        const end = at + @as(usize, @intCast(length));
        captures[made] = try allocator.dupe(u8, bytes[at..end]);
        at = end;
    }
    return captures;
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
