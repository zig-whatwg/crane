//! Converting to HeadersInit - (sequence<sequence<ByteString>> or
//! record<ByteString, ByteString>), the init of Headers, Request and
//! Response, and so of every fetch() - through the V8 adapter's conversion.
//!
//! WebIDL 3.2.25 step 11.2: an Object whose @@iterator is not undefined is the
//! sequence member, "created from" that method - an Array, but equally a
//! Map, a generator or a Headers object (its pair iterator yields [name,
//! value]). Only an Object without one is the record (11.5); a primitive is
//! neither (19, a TypeError). Each string is a ByteString (3.2.11): a code
//! unit above 0xFF is a TypeError.
//!
//! The conversion used to test IsArray where the union says @@iterator, so a
//! Headers object passed as `headers` read as a record of its own enumerable
//! properties - none - and every header was dropped.
//!
//! Values are made the way the binding makes an argument (a Global the
//! script's value was copied into), converted with std.testing.allocator and
//! freed with the binding's own `freeConvertedArg`, so a string or slice the
//! conversion leaves behind fails the test. Each conversion runs under a
//! TryCatch (v8_RunCatching): what script throws while converting is the
//! test's to see, not left pending.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const engine = @import("engine");
const ffi = v8.ffi;
const conv = v8.conversions;
const HeadersInit = conv.generated_typedefs.HeadersInit;

const Env = struct {
    isolate: *ffi.Isolate,
    context: *ffi.Context,
};

var env_once: ?Env = null;

/// One isolate and context for the file; V8 is never torn down here.
fn env() !Env {
    if (env_once) |e| return e;
    try engine.initializeEngine(.{});
    const isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(isolate);
    _ = ffi.v8_HandleScope_New(isolate);
    const context = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    env_once = .{ .isolate = isolate, .context = context };
    return env_once.?;
}

/// The value `code` evaluates to: a Global the caller disposes, made the way
/// the binding's `info.get(i)` makes an argument's.
fn eval(code: []const u8) !*ffi.Value {
    const e = try env();
    const text = ffi.v8_String_NewFromUtf8(e.isolate, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(e.context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(e.context, script) orelse error.RunFailed;
}

/// `value`'s ToString, written into `buffer`.
fn stringOf(value: *ffi.Value, buffer: []u8) ![]const u8 {
    const string = ffi.v8_Value_ToString(value, env_once.?.context) orelse return error.ToStringFailed;
    defer ffi.v8_String_Dispose(string);
    const length: usize = @intCast(ffi.v8_String_Utf8Length(string));
    if (length > buffer.len) return error.TooLong;
    _ = ffi.v8_String_WriteUtf8(string, buffer.ptr, @intCast(length));
    return buffer[0..length];
}

/// `code`'s value as a string (its ToString), for checking what script saw.
fn evalString(code: []const u8, buffer: []u8) ![]const u8 {
    const value = try eval(code);
    defer ffi.v8_Value_Dispose(value);
    return stringOf(value, buffer);
}

/// One conversion of `handle`, run under a TryCatch.
const Conversion = struct {
    handle: *ffi.Value,
    result: conv.ConversionError!HeadersInit = error.TypeError,
    /// What script threw, OWNED; null when nothing was thrown.
    thrown: ?*ffi.Value = null,

    fn body(data: ?*anyopaque) callconv(.c) void {
        const self: *Conversion = @ptrCast(@alignCast(data.?));
        const e = env_once.?;
        self.result = conv.fromV8Value(HeadersInit, testing.allocator, e.isolate, e.context, self.handle);
    }

    fn run(handle: *ffi.Value) Conversion {
        var self: Conversion = .{ .handle = handle };
        _ = ffi.v8_RunCatching(env_once.?.isolate, body, &self, &self.thrown);
        return self;
    }

    fn deinit(self: *Conversion) void {
        if (self.result) |value| v8.interface_mod.freeConvertedArg(HeadersInit, testing.allocator, value) else |_| {}
        if (self.thrown) |t| ffi.v8_Value_Dispose(t);
    }
};

const Pair = [2][]const u8;

/// `code` converts to the sequence member, each inner sequence the pair given.
fn expectSequence(code: []const u8, expected: []const Pair) !void {
    const handle = try eval(code);
    defer ffi.v8_Value_Dispose(handle);
    var conversion = Conversion.run(handle);
    defer conversion.deinit();
    const value = conversion.result catch |err| {
        std.debug.print("{s} did not convert: {s}\n", .{ code, @errorName(err) });
        return err;
    };
    const items = switch (value) {
        .sequence_byte_string_sequence => |items| items,
        .byte_string_byte_string_record => {
            std.debug.print("{s} converted to the record member\n", .{code});
            return error.TestUnexpectedResult;
        },
    };
    try testing.expectEqual(expected.len, items.len);
    for (expected, items) |pair, item| {
        try testing.expectEqual(@as(usize, 2), item.len);
        try testing.expectEqualStrings(pair[0], item[0]);
        try testing.expectEqualStrings(pair[1], item[1]);
    }
}

/// `code` converts to the record member, its entries in order.
fn expectRecord(code: []const u8, expected: []const Pair) !void {
    const handle = try eval(code);
    defer ffi.v8_Value_Dispose(handle);
    var conversion = Conversion.run(handle);
    defer conversion.deinit();
    const value = conversion.result catch |err| {
        std.debug.print("{s} did not convert: {s}\n", .{ code, @errorName(err) });
        return err;
    };
    const entries = switch (value) {
        .byte_string_byte_string_record => |entries| entries,
        .sequence_byte_string_sequence => {
            std.debug.print("{s} converted to the sequence member\n", .{code});
            return error.TestUnexpectedResult;
        },
    };
    try testing.expectEqual(expected.len, entries.len);
    for (expected, entries) |pair, entry| {
        try testing.expectEqualStrings(pair[0], entry.key);
        try testing.expectEqualStrings(pair[1], entry.value);
    }
}

/// `code` is a TypeError: one the binding throws (error.TypeError), or one
/// script threw while converting (V8's own, an iterator's).
fn expectTypeError(code: []const u8) !void {
    const handle = try eval(code);
    defer ffi.v8_Value_Dispose(handle);
    var conversion = Conversion.run(handle);
    defer conversion.deinit();
    if (conversion.result) |_| {
        std.debug.print("{s} converted; a TypeError was expected\n", .{code});
        return error.TestUnexpectedResult;
    } else |err| switch (err) {
        error.TypeError => {},
        error.ExceptionPending => {
            const thrown = conversion.thrown orelse return error.NothingThrown;
            var buffer: [128]u8 = undefined;
            const text = try stringOf(thrown, &buffer);
            if (!std.mem.startsWith(u8, text, "TypeError")) {
                std.debug.print("{s} threw {s}, not a TypeError\n", .{ code, text });
                return error.TestUnexpectedResult;
            }
        },
        else => {
            std.debug.print("{s}: {s}, not a TypeError\n", .{ code, @errorName(err) });
            return err;
        },
    }
}

/// `code` throws while converting, and what it throws propagates.
fn expectThrown(code: []const u8, message: []const u8) !void {
    const handle = try eval(code);
    defer ffi.v8_Value_Dispose(handle);
    var conversion = Conversion.run(handle);
    defer conversion.deinit();
    try testing.expectError(error.ExceptionPending, conversion.result);
    const thrown = conversion.thrown orelse return error.NothingThrown;
    var buffer: [64]u8 = undefined;
    try testing.expectEqualStrings(message, try stringOf(thrown, &buffer));
}

// ---- step 11.2: any iterable is the sequence member ----

test "an Array of pairs is the sequence member" {
    try expectSequence("[['a', 'b'], ['c', 'd']]", &.{ .{ "a", "b" }, .{ "c", "d" } });
    try expectSequence("[]", &.{});
}

test "a Map is the sequence member, not a record of its own properties" {
    try expectSequence("new Map([['a', 'b'], ['c', 'd']])", &.{ .{ "a", "b" }, .{ "c", "d" } });
}

test "a generator is the sequence member, and its pairs may be iterables too" {
    try expectSequence("(function* () { yield ['a', 'b']; yield new Set(['c', 'd']); })()", &.{ .{ "a", "b" }, .{ "c", "d" } });
}

test "an object with its own @@iterator is the sequence member" {
    // headers-basic.any.js, "Create headers with existing headers with
    // custom iterator": the method is the object's, whatever else it holds.
    try expectSequence("({ x: 'y', *[Symbol.iterator]() { yield ['test', 'test']; } })", &.{.{ "test", "test" }});
}

test "a pair that is no Object is a TypeError" {
    // 3.2.21 step 1 for the inner sequence<ByteString>.
    try expectTypeError("[['a', 'b'], 'cd']");
    // 3.2.21 step 3: an Object with no @@iterator.
    try expectTypeError("[{ 0: 'a', 1: 'b', length: 2 }]");
}

test "an @@iterator that is not callable is a TypeError" {
    // GetMethod step 3.
    try expectTypeError("({ [Symbol.iterator]: 1 })");
}

test "what the iterator throws propagates" {
    try expectThrown("({ [Symbol.iterator]() { throw 'boom'; } })", "boom");
    try expectThrown("({ [Symbol.iterator]() { return { next() { throw 'next'; } }; } })", "next");
    try expectThrown("[['a', { toString() { throw 'item'; } }]]", "item");
}

test "an item is converted before the next one is asked for" {
    // 3.2.21.1 step 3: IteratorStepValue, then converting `next`, in turn.
    try expectSequence(
        \\(globalThis.order = [], (function* () {
        \\  order.push('next 1'); yield [{ toString() { order.push('convert 1'); return 'a'; } }, 'b'];
        \\  order.push('next 2'); yield ['c', 'd'];
        \\})())
    , &.{ .{ "a", "b" }, .{ "c", "d" } });
    var buffer: [128]u8 = undefined;
    try testing.expectEqualStrings("next 1,convert 1,next 2", try evalString("order.join()", &buffer));
}

// ---- step 11.5: any other Object is the record member ----

test "an Object without @@iterator is the record member" {
    try expectRecord("({ a: 'b', c: 'd' })", &.{ .{ "a", "b" }, .{ "c", "d" } });
    try expectRecord("({})", &.{});
    // ToString of the values: headers-basic's headerDict.
    try expectRecord("({ n: null, u: undefined, one: 1 })", &.{ .{ "n", "null" }, .{ "u", "undefined" }, .{ "one", "1" } });
}

test "the record reads its keys, descriptors and values in the record conversion's order" {
    // headers-record.any.js: [[Get]] of @@iterator (the union's step 11.2),
    // [[OwnPropertyKeys]], then per key [[GetOwnProperty]] and, for an
    // enumerable one, [[Get]]; a non-enumerable key is skipped.
    try expectRecord(
        \\(globalThis.log = [], (() => {
        \\  const record = {};
        \\  Object.defineProperty(record, 'a', { value: 'b', enumerable: false });
        \\  Object.defineProperty(record, 'c', { value: 'd', enumerable: true });
        \\  const handler = {};
        \\  for (const trap of ['get', 'ownKeys', 'getOwnPropertyDescriptor'])
        \\    handler[trap] = (...args) => { log.push(trap + ':' + String(args[1] ?? '')); return Reflect[trap](...args); };
        \\  return new Proxy(record, handler);
        \\})())
    , &.{.{ "c", "d" }});
    var buffer: [256]u8 = undefined;
    try testing.expectEqualStrings(
        "get:Symbol(Symbol.iterator),ownKeys:,getOwnPropertyDescriptor:a,getOwnPropertyDescriptor:c,get:c",
        try evalString("log.join()", &buffer),
    );
}

test "an enumerable Symbol key is a TypeError, a non-enumerable one is skipped" {
    try expectTypeError("({ a: 'b', [Symbol.toStringTag]: 'x' })");
    try expectRecord("Object.defineProperty({ a: 'b' }, Symbol.toStringTag, { value: 'x', enumerable: false })", &.{.{ "a", "b" }});
}

// ---- step 19: a primitive is neither member ----

test "a primitive is a TypeError" {
    try expectTypeError("null");
    try expectTypeError("'a: b'");
    try expectTypeError("1");
    try expectTypeError("true");
}

// ---- ByteString (3.2.11): a code unit above 0xFF is a TypeError ----

test "a code unit above 0xFF in a name or a value is a TypeError" {
    try expectTypeError("[['\\u0100', 'b']]");
    try expectTypeError("[['a', '\\uFFFF']]");
    try expectTypeError("({ '\\uFFFF': 'd' })");
    try expectTypeError("({ a: '\\uFFFF' })");
    // A lone surrogate is a code unit above 0xFF too.
    try expectTypeError("[['a', '\\uD800']]");
}

test "code units up to 0xFF are a ByteString" {
    // Held as UTF-8 text, as every Crane string: U+00E9 is C3 A9.
    try expectSequence("[['a', '\\u00e9\\u00ff\\u0080']]", &.{.{ "a", "\u{e9}\u{ff}\u{80}" }});
    try expectRecord("({ a: '\\u00e9' })", &.{.{ "a", "\u{e9}" }});
}

test "codeUnitsFitInByte reads the code units WTF-8 encodes" {
    try testing.expect(conv.codeUnitsFitInByte("plain ASCII"));
    try testing.expect(conv.codeUnitsFitInByte("\u{80}\u{ff}"));
    try testing.expect(!conv.codeUnitsFitInByte("\u{100}"));
    try testing.expect(!conv.codeUnitsFitInByte("\u{1F600}"));
}

// ---- handles ----

/// Global handle bytes left after converting `code`'s value 64 times, once a
/// first round has made what later ones reuse.
fn handleBytesLeftBy(code: []const u8) !i64 {
    const e = try env();
    const handle = try eval(code);
    defer ffi.v8_Value_Dispose(handle);
    for (0..2) |round| {
        const before: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(e.isolate));
        for (0..64) |_| {
            var conversion = Conversion.run(handle);
            conversion.deinit();
        }
        const after: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(e.isolate));
        if (round == 1) return after - before;
    }
    unreachable;
}

test "converting keeps no handle" {
    // Every Get, method, iterator and item is the conversion's to release.
    const cases = [_][]const u8{
        "[['a', 'b'], ['c', 'd']]",
        "new Map([['a', 'b']])",
        "({ *[Symbol.iterator]() { yield ['a', 'b']; yield new Set(['c', 'd']); } })",
        "({ a: 'b', c: 'd' })",
        "[['a', '\\u0100']]",
        "({ a: '\\u0100' })",
    };
    for (cases) |code| {
        const left = try handleBytesLeftBy(code);
        if (left > 0) {
            std.debug.print("{s}: {d} global handle bytes left over 64 conversions\n", .{ code, left });
            return error.HandleLeftPerConversion;
        }
    }
}
