//! The Engine table's WebIDL conversions, as V8 implements them
//! (webidl_conversions.zig): convertToDOMString, convertToUSVString,
//! convertToSequenceOfDOMStrings, convertToPlatformObject,
//! getCopyOfBufferSourceBytes and createSequenceOfValues - the shared set an
//! impl uses for an argument it takes unconverted (a union, a BufferSource).
//!
//! The spec's edge cases, each pinned: a Symbol, a throwing toString, a lone
//! surrogate, a detached buffer, a SharedArrayBuffer, a view's own window of
//! its buffer, an object with no @@iterator in a union with a sequence.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;

const engine = &v8.engine.v8_engine_interface;
const allocator = std.testing.allocator;

var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;
var data_once: ?*runtime.ContextData = null;

fn realm() !runtime.Context {
    if (data_once) |d| return d;
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    const data = try std.heap.page_allocator.create(runtime.ContextData);
    data.* = try runtime.ContextData.init(std.heap.page_allocator, .{ .engine = engine, .engine_ctx = context });
    data.agent = @ptrCast(i);
    isolate_once = i;
    context_once = context;
    data_once = data;
    return data;
}

fn eval(code: []const u8) !*ffi.Value {
    const context = context_once.?;
    const text = ffi.v8_String_NewFromUtf8(isolate_once.?, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse error.RunFailed;
}

fn evalInt(code: []const u8) !i32 {
    const value = try eval(code);
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, context_once.?);
}

fn setGlobal(name: []const u8, handle: *anyopaque) !void {
    const context = context_once.?;
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(isolate_once.?, name.ptr, @intCast(name.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    _ = ffi.v8_Object_Set(global, context, @ptrCast(key), @ptrCast(@alignCast(handle)));
}

fn asValue(handle: *ffi.Value) runtime.JSValue {
    return .{ .handle = .{ .ptr = @ptrCast(handle), .needs_disposal = false, .handle_scope = .global } };
}

/// A value made by `code`, as a borrowed JSValue, and the Global to dispose.
const Made = struct {
    handle: *ffi.Value,
    fn of(code: []const u8) !Made {
        return .{ .handle = try eval(code) };
    }
    fn value(self: Made) runtime.JSValue {
        return asValue(self.handle);
    }
    fn deinit(self: Made) void {
        ffi.v8_Value_Dispose(self.handle);
    }
};

// ----------------------------------------------------------------------------
// DOMString / USVString
// ----------------------------------------------------------------------------

test "ToString of objects, numbers and strings" {
    const ctx = try realm();
    const object = try Made.of("({ toString() { return 'custom'; } })");
    defer object.deinit();
    const text = try engine.convertToDOMString.?(ctx, object.value(), allocator);
    defer allocator.free(text);
    try std.testing.expectEqualStrings("custom", text);

    const number = try engine.convertToDOMString.?(ctx, .{ .number = 1.5 }, allocator);
    defer allocator.free(number);
    try std.testing.expectEqualStrings("1.5", number);

    const already = try engine.convertToDOMString.?(ctx, runtime.JSValue.fromStringRef("as is"), allocator);
    defer allocator.free(already);
    try std.testing.expectEqualStrings("as is", already);
}

test "a Symbol is a TypeError with nothing thrown" {
    const ctx = try realm();
    const symbol = try Made.of("Symbol('s')");
    defer symbol.deinit();
    try std.testing.expectError(error.TypeError, engine.convertToDOMString.?(ctx, symbol.value(), allocator));
    try std.testing.expectError(error.TypeError, engine.convertToUSVString.?(ctx, symbol.value(), allocator));
}

test "a lone surrogate becomes U+FFFD in a USVString" {
    const ctx = try realm();
    const lone = try Made.of("'a\\uD800b'");
    defer lone.deinit();
    const usv = try engine.convertToUSVString.?(ctx, lone.value(), allocator);
    defer allocator.free(usv);
    try std.testing.expectEqualStrings("a\u{FFFD}b", usv);
}

/// A native that converts its argument to a DOMString and returns its length,
/// or -1 for a TypeError; an ExceptionPending returns nothing.
fn stringLength(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const argument = info.get(0);
    defer ffi.v8_Global_Dispose(argument);
    // As an impl gets it: the binding's form of the argument (an object is a
    // `.handle` tagged `.local` whose pointer is the argument's Global).
    var value = v8.conversions.fromV8Value(runtime.JSValue, allocator, isolate_once.?, context_once.?, argument) catch return;
    defer value.deinit(allocator);
    const result: f64 = if (engine.convertToDOMString.?(data_once.?, value, allocator)) |text| blk: {
        defer allocator.free(text);
        break :blk @floatFromInt(text.len);
    } else |err| switch (err) {
        error.ExceptionPending => return,
        else => -1,
    };
    const number = ffi.v8_Number_New(info.getIsolate(), result);
    defer ffi.v8_Value_Dispose(@ptrCast(number));
    info.setReturnValue(@ptrCast(number));
}

fn installNative(name: []const u8, callback: ffi.FunctionCallback) !void {
    const context = context_once.?;
    const template = ffi.v8_FunctionTemplate_New(isolate_once.?, callback, null) orelse return error.TemplateFailed;
    defer ffi.v8_FunctionTemplate_Dispose(template);
    const function = ffi.v8_FunctionTemplate_GetFunction(template, context) orelse return error.FunctionFailed;
    defer ffi.v8_Function_Dispose(function);
    try setGlobal(name, @ptrCast(function));
}

test "a throwing toString propagates to the calling script" {
    _ = try realm();
    try installNative("stringLength", stringLength);
    try std.testing.expectEqual(@as(i32, 3), try evalInt("stringLength({ toString() { return 'abc'; } })"));
    try std.testing.expectEqual(@as(i32, -1), try evalInt("stringLength(Symbol())"));
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\(() => {
        \\  const boom = new Error("toString");
        \\  try { stringLength({ toString() { throw boom; } }); } catch (e) { return e === boom ? 1 : 0; }
        \\  return -1;
        \\})()
    ));
}

// ----------------------------------------------------------------------------
// sequence<DOMString>, as a union member
// ----------------------------------------------------------------------------

fn freeStrings(strings: [][]u8) void {
    for (strings) |string| allocator.free(string);
    allocator.free(strings);
}

test "an iterable converts to its strings, each by ToString" {
    const ctx = try realm();
    const array = try Made.of("['a', 2, { toString() { return 'c'; } }]");
    defer array.deinit();
    const strings = (try engine.convertToSequenceOfDOMStrings.?(ctx, array.value(), allocator)).?;
    defer freeStrings(strings);
    try std.testing.expectEqual(@as(usize, 3), strings.len);
    try std.testing.expectEqualStrings("a", strings[0]);
    try std.testing.expectEqualStrings("2", strings[1]);
    try std.testing.expectEqualStrings("c", strings[2]);

    const set = try Made.of("new Set(['x', 'y'])");
    defer set.deinit();
    const from_set = (try engine.convertToSequenceOfDOMStrings.?(ctx, set.value(), allocator)).?;
    defer freeStrings(from_set);
    try std.testing.expectEqual(@as(usize, 2), from_set.len);
}

test "an object with no @@iterator is not a sequence (null), and a non-object is a TypeError" {
    const ctx = try realm();
    const plain = try Made.of("({ length: 1, 0: 'a' })");
    defer plain.deinit();
    try std.testing.expectEqual(@as(?[][]u8, null), try engine.convertToSequenceOfDOMStrings.?(ctx, plain.value(), allocator));
    try std.testing.expectError(error.TypeError, engine.convertToSequenceOfDOMStrings.?(ctx, .{ .number = 1 }, allocator));
    // A String object IS iterable: its characters.
    const boxed = try Made.of("new String('ab')");
    defer boxed.deinit();
    const chars = (try engine.convertToSequenceOfDOMStrings.?(ctx, boxed.value(), allocator)).?;
    defer freeStrings(chars);
    try std.testing.expectEqual(@as(usize, 2), chars.len);
}

// ----------------------------------------------------------------------------
// record<K, V> of strings (WebIDL 3.2.23)
// ----------------------------------------------------------------------------

fn freeRecord(entries: []runtime.StringRecordEntry) void {
    runtime.StringRecordEntry.freeAll(entries, allocator);
}

test "a record is the object's own enumerable properties, in [[OwnPropertyKeys]] order" {
    const ctx = try realm();
    // The spec's own example: the prototype's and the non-enumerable
    // property are not in it; integer keys come first, ascending.
    const object = try Made.of(
        \\(() => {
        \\  const proto = { a: 3, b: 4 };
        \\  const obj = { __proto__: proto, d: 5, c: 'six', 2: 'two', 1: { toString() { return 'one'; } } };
        \\  Object.defineProperty(obj, 'e', { value: 7, enumerable: false });
        \\  Object.defineProperty(obj, Symbol('hidden'), { value: 8, enumerable: false });
        \\  return obj;
        \\})()
    );
    defer object.deinit();
    const record = try engine.convertToRecordOfStrings.?(ctx, object.value(), .usv_string, .usv_string, allocator);
    defer freeRecord(record);
    try std.testing.expectEqual(@as(usize, 4), record.len);
    try std.testing.expectEqualStrings("1", record[0].key);
    try std.testing.expectEqualStrings("one", record[0].value);
    try std.testing.expectEqualStrings("2", record[1].key);
    try std.testing.expectEqualStrings("two", record[1].value);
    try std.testing.expectEqualStrings("d", record[2].key);
    try std.testing.expectEqualStrings("5", record[2].value);
    try std.testing.expectEqualStrings("c", record[3].key);
    try std.testing.expectEqualStrings("six", record[3].value);

    const empty = try Made.of("({})");
    defer empty.deinit();
    const none = try engine.convertToRecordOfStrings.?(ctx, empty.value(), .dom_string, .dom_string, allocator);
    defer freeRecord(none);
    try std.testing.expectEqual(@as(usize, 0), none.len);
}

test "USVString keys that collide after U+FFFD replacement are one entry, set in place" {
    const ctx = try realm();
    const object = try Made.of("({ '\\uD83D': 'first', z: 'z', '\\uFFFD': 'second', v: 'a\\uD800b' })");
    defer object.deinit();
    const usv = try engine.convertToRecordOfStrings.?(ctx, object.value(), .usv_string, .usv_string, allocator);
    defer freeRecord(usv);
    try std.testing.expectEqual(@as(usize, 3), usv.len);
    try std.testing.expectEqualStrings("\u{FFFD}", usv[0].key);
    try std.testing.expectEqualStrings("second", usv[0].value);
    try std.testing.expectEqualStrings("z", usv[1].key);
    try std.testing.expectEqualStrings("v", usv[2].key);
    try std.testing.expectEqualStrings("a\u{FFFD}b", usv[2].value);

    // As DOMStrings, the lone surrogate stays: two keys.
    const dom = try engine.convertToRecordOfStrings.?(ctx, object.value(), .dom_string, .dom_string, allocator);
    defer freeRecord(dom);
    try std.testing.expectEqual(@as(usize, 4), dom.len);
    try std.testing.expect(!std.mem.eql(u8, dom[0].key, dom[2].key));
}

test "a non-object, and an enumerable Symbol-keyed property, are TypeErrors" {
    const ctx = try realm();
    try std.testing.expectError(error.TypeError, engine.convertToRecordOfStrings.?(ctx, .{ .number = 1 }, .usv_string, .usv_string, allocator));
    try std.testing.expectError(error.TypeError, engine.convertToRecordOfStrings.?(ctx, runtime.JSValue.fromStringRef("a=b"), .usv_string, .usv_string, allocator));
    try std.testing.expectError(error.TypeError, engine.convertToRecordOfStrings.?(ctx, runtime.JSValue.jsNull, .usv_string, .usv_string, allocator));
    const symbol = try Made.of("Symbol('s')");
    defer symbol.deinit();
    try std.testing.expectError(error.TypeError, engine.convertToRecordOfStrings.?(ctx, symbol.value(), .usv_string, .usv_string, allocator));
    const keyed = try Made.of("({ a: '1', [Symbol('k')]: '2' })");
    defer keyed.deinit();
    try std.testing.expectError(error.TypeError, engine.convertToRecordOfStrings.?(ctx, keyed.value(), .usv_string, .usv_string, allocator));
    // A Symbol VALUE does not convert to a string either.
    const valued = try Made.of("({ a: Symbol('v') })");
    defer valued.deinit();
    try std.testing.expectError(error.TypeError, engine.convertToRecordOfStrings.?(ctx, valued.value(), .dom_string, .dom_string, allocator));
}

/// A native that converts its argument to a record<USVString, USVString> as
/// an impl does, from the binding's form of the argument, and returns its
/// entry count - or -1 for a TypeError; an ExceptionPending returns nothing.
fn recordSize(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const argument = info.get(0);
    defer ffi.v8_Global_Dispose(argument);
    var value = v8.conversions.fromV8Value(runtime.JSValue, allocator, isolate_once.?, context_once.?, argument) catch return;
    defer value.deinit(allocator);
    const result: f64 = if (engine.convertToRecordOfStrings.?(data_once.?, value, .usv_string, .usv_string, allocator)) |record| blk: {
        defer freeRecord(record);
        break :blk @floatFromInt(record.len);
    } else |err| switch (err) {
        error.ExceptionPending => return,
        else => -1,
    };
    const number = ffi.v8_Number_New(info.getIsolate(), result);
    defer ffi.v8_Value_Dispose(@ptrCast(number));
    info.setReturnValue(@ptrCast(number));
}

test "a proxy sees ownKeys, then per key getOwnPropertyDescriptor and get - and only for enumerable keys" {
    _ = try realm();
    try installNative("recordSize", recordSize);
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\(() => {
        \\  const log = [];
        \\  const target = { a: '1', b: '2' };
        \\  Object.defineProperty(target, 'hidden', { value: 'x', enumerable: false });
        \\  const proxy = new Proxy(target, {
        \\    ownKeys(t) { log.push('ownKeys'); return Reflect.ownKeys(t); },
        \\    getOwnPropertyDescriptor(t, k) { log.push('gopd:' + String(k)); return Reflect.getOwnPropertyDescriptor(t, k); },
        \\    get(t, k, r) { log.push('get:' + String(k)); return Reflect.get(t, k, r); },
        \\  });
        \\  const size = recordSize(proxy);
        \\  globalThis.recordLog = log.join(',');
        \\  return size === 2 && globalThis.recordLog === 'ownKeys,gopd:a,get:a,gopd:b,get:b,gopd:hidden' ? 1 : 0;
        \\})()
    ));
    try std.testing.expectEqual(@as(i32, -1), try evalInt("recordSize(5)"));
}

test "what a trap, a getter or a toString throws propagates to the calling script" {
    _ = try realm();
    try installNative("recordSize", recordSize);
    try std.testing.expectEqual(@as(i32, 3), try evalInt(
        \\(() => {
        \\  let caught = 0;
        \\  const boom = new Error('boom');
        \\  const cases = [
        \\    new Proxy({}, { ownKeys() { throw boom; } }),
        \\    new Proxy({ a: 1 }, { getOwnPropertyDescriptor() { throw boom; } }),
        \\    { get a() { throw boom; } },
        \\    { a: { toString() { throw boom; } } },
        \\  ];
        \\  for (const c of cases) { try { recordSize(c); } catch (e) { if (e === boom) caught++; } }
        \\  return caught - 1;
        \\})()
    ));
}

// ----------------------------------------------------------------------------
// BufferSource
// ----------------------------------------------------------------------------

test "an ArrayBuffer's bytes, and a view's own window of its buffer" {
    const ctx = try realm();
    const buffer = try Made.of("globalThis.b = new Uint8Array([1, 2, 3, 4, 5]).buffer; b");
    defer buffer.deinit();
    const all = (try engine.getCopyOfBufferSourceBytes.?(ctx, buffer.value(), allocator)).?;
    defer allocator.free(all);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4, 5 }, all);

    const view = try Made.of("new Uint8Array(b, 1, 3)");
    defer view.deinit();
    const window = (try engine.getCopyOfBufferSourceBytes.?(ctx, view.value(), allocator)).?;
    defer allocator.free(window);
    try std.testing.expectEqualSlices(u8, &.{ 2, 3, 4 }, window);

    const data_view = try Made.of("new DataView(b, 3)");
    defer data_view.deinit();
    const tail = (try engine.getCopyOfBufferSourceBytes.?(ctx, data_view.value(), allocator)).?;
    defer allocator.free(tail);
    try std.testing.expectEqualSlices(u8, &.{ 4, 5 }, tail);
}

test "a detached buffer holds no bytes, and neither does a view of one" {
    const ctx = try realm();
    const detached = try Made.of("globalThis.d = new ArrayBuffer(8); globalThis.dv = new Uint8Array(d); d.transfer(); d");
    defer detached.deinit();
    const none = (try engine.getCopyOfBufferSourceBytes.?(ctx, detached.value(), allocator)).?;
    defer allocator.free(none);
    try std.testing.expectEqual(@as(usize, 0), none.len);
    const view = try Made.of("dv");
    defer view.deinit();
    const view_none = (try engine.getCopyOfBufferSourceBytes.?(ctx, view.value(), allocator)).?;
    defer allocator.free(view_none);
    try std.testing.expectEqual(@as(usize, 0), view_none.len);
}

test "a SharedArrayBuffer is not a BufferSource, and a view of one is a TypeError" {
    const ctx = try realm();
    const shared = try Made.of("globalThis.sab = new SharedArrayBuffer(4); sab");
    defer shared.deinit();
    try std.testing.expectEqual(@as(?[]u8, null), try engine.getCopyOfBufferSourceBytes.?(ctx, shared.value(), allocator));
    const view = try Made.of("new Uint8Array(sab)");
    defer view.deinit();
    try std.testing.expectError(error.TypeError, engine.getCopyOfBufferSourceBytes.?(ctx, view.value(), allocator));
}

test "anything else is not a BufferSource" {
    const ctx = try realm();
    const object = try Made.of("({})");
    defer object.deinit();
    try std.testing.expectEqual(@as(?[]u8, null), try engine.getCopyOfBufferSourceBytes.?(ctx, object.value(), allocator));
    try std.testing.expectEqual(@as(?[]u8, null), try engine.getCopyOfBufferSourceBytes.?(ctx, .{ .number = 3 }, allocator));
}

// ----------------------------------------------------------------------------
// Platform objects and sequences back to script
// ----------------------------------------------------------------------------

const mock_methods: u8 = 0;
const mock_vtable = runtime.VTable{ .name = "MockBlob", .deinit = null, .methods_ptr = &mock_methods };
var mock_blob: runtime.Instance = undefined;

test "a platform object converts to its Instance; nothing else does" {
    const ctx = try realm();
    const template = ffi.v8_ObjectTemplate_New(isolate_once.?);
    defer ffi.v8_ObjectTemplate_Dispose(template);
    ffi.v8_ObjectTemplate_SetInternalFieldCount(template, 2);
    mock_blob = .{ .vtable = &mock_vtable, .state = undefined, .ctx = ctx };
    const object = ffi.v8_ObjectTemplate_NewInstance(template, context_once.?) orelse return error.InstanceFailed;
    defer ffi.v8_Object_Dispose(object);
    ffi.v8_Object_SetAlignedPointerInInternalField(object, 0, @ptrCast(&mock_blob));
    ffi.v8_Object_SetAlignedPointerInInternalField(object, 1, null);

    try std.testing.expectEqual(@as(?*runtime.Instance, &mock_blob), engine.convertToPlatformObject.?(ctx, asValue(@ptrCast(object))));
    const plain = try Made.of("({})");
    defer plain.deinit();
    try std.testing.expectEqual(@as(?*runtime.Instance, null), engine.convertToPlatformObject.?(ctx, plain.value()));
    const function = try Made.of("(function () {})");
    defer function.deinit();
    try std.testing.expectEqual(@as(?*runtime.Instance, null), engine.convertToPlatformObject.?(ctx, function.value()));
    try std.testing.expectEqual(@as(?*runtime.Instance, null), engine.convertToPlatformObject.?(ctx, .{ .number = 1 }));
}

test "a sequence of values becomes an Array of the realm" {
    const ctx = try realm();
    const object = try Made.of("globalThis.o = {}; o");
    defer object.deinit();
    const array = try engine.createSequenceOfValues.?(ctx, &.{ .{ .number = 7 }, runtime.JSValue.fromStringRef("s"), object.value() });
    defer engine.releaseValue.?(array);
    try std.testing.expect(array.handle.needs_disposal);
    try setGlobal("arr", array.handle.ptr);
    try std.testing.expectEqual(@as(i32, 1), try evalInt("Array.isArray(arr) && arr.length === 3 && arr[0] === 7 && arr[1] === 's' && arr[2] === o ? 1 : 0"));
}

// ============================================================================
// The engine protocol's values, callbacks, iteration and sequences
// (design 4.4-4.7), bound to V8
// ============================================================================
//
// `@import("engine")` - under another name here only because this file already
// calls the table `engine`. Arguments are made as the binding makes them
// (conversions.fromV8Value): an object is a `.handle` tagged `.local`.

const protocol = @import("engine");

/// `handle` as the binding hands it to an impl. Call `deinit` on the result.
fn bound(handle: *ffi.Value) !runtime.JSValue {
    return v8.conversions.fromV8Value(runtime.JSValue, allocator, isolate_once.?, context_once.?, handle);
}

/// Run `body.run()` as script calling a binding would: under a TryCatch.
/// What it threw (OWNED), or null.
fn thrownBy(body: anytype) ?*ffi.Value {
    const Body = @TypeOf(body.*);
    const Trampoline = struct {
        fn call(data: ?*anyopaque) callconv(.c) void {
            const self: *Body = @ptrCast(@alignCast(data.?));
            self.run();
        }
    };
    var thrown: ?*ffi.Value = null;
    _ = ffi.v8_RunCatching(isolate_once.?, Trampoline.call, body, &thrown);
    return thrown;
}

/// Whether script's `expression` over `name` (bound to `value`) is true.
fn holds(name: []const u8, value: *anyopaque, expression: []const u8) !bool {
    try setGlobal(name, value);
    return try evalInt(expression) == 1;
}

fn int32Of(owned: protocol.Owned) i32 {
    return ffi.v8_Value_Int32Value(@ptrCast(@alignCast(owned.value.handle.ptr)), context_once.?);
}

test "protocol: Get reads a property, and what a getter throws is pending" {
    const ctx = try realm();
    const object = try Made.of("({ a: 1, get boom() { throw globalThis.boom = new Error('get'); } })");
    defer object.deinit();
    var argument = try bound(object.handle);
    defer argument.deinit(allocator);

    const a = try protocol.getProperty(ctx, argument, "a");
    defer a.release();
    try std.testing.expectEqual(@as(i32, 1), int32Of(a));
    const missing = try protocol.getProperty(ctx, argument, "nope");
    defer missing.release();
    try std.testing.expectEqual(protocol.ValueType.undefined, protocol.typeOf(ctx, missing.value));

    var body: struct {
        ctx: runtime.Context,
        argument: runtime.JSValue,
        result: protocol.Error!protocol.Owned = undefined,
        fn run(self: *@This()) void {
            self.result = protocol.getProperty(self.ctx, self.argument, "boom");
        }
    } = .{ .ctx = ctx, .argument = argument };
    const thrown = thrownBy(&body) orelse return error.NothingThrown;
    defer ffi.v8_Global_Dispose(thrown);
    try std.testing.expectError(error.ExceptionPending, body.result);
    try std.testing.expect(try holds("thrownGet", thrown, "thrownGet === globalThis.boom ? 1 : 0"));

    try std.testing.expectError(error.TypeError, protocol.getProperty(ctx, runtime.JSValue.fromNumber(1), "a"));
}

test "protocol: Set and DefinePropertyOrThrow write, HasProperty reads, and a failed define is a TypeError" {
    const ctx = try realm();
    const object = try Made.of("globalThis.target = Object.create({ inherited: 1 })");
    defer object.deinit();
    var argument = try bound(object.handle);
    defer argument.deinit(allocator);

    try protocol.setProperty(ctx, argument, "plain", runtime.JSValue.fromNumber(7));
    try protocol.defineOwnProperty(ctx, argument, "hidden", runtime.JSValue.fromStringRef("h"), .{ .writable = false, .enumerable = false, .configurable = false });
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\target.plain === 7 && target.hidden === "h" && Object.keys(target).join() === "plain" &&
        \\!Object.getOwnPropertyDescriptor(target, "hidden").writable ? 1 : 0
    ));
    try std.testing.expect(try protocol.hasProperty(ctx, argument, "inherited"));
    try std.testing.expect(try protocol.hasProperty(ctx, argument, "hidden"));
    try std.testing.expect(!try protocol.hasProperty(ctx, argument, "absent"));
    // DefinePropertyOrThrow: [[DefineOwnProperty]] returned false.
    try std.testing.expectError(error.TypeError, protocol.defineOwnProperty(ctx, argument, "hidden", runtime.JSValue.fromNumber(1), .{ .writable = true, .enumerable = true, .configurable = true }));
    // The deviation, pinned: V8's embedder Set is sloppy, so a Set that fails
    // without throwing reports success.
    try protocol.setProperty(ctx, argument, "hidden", runtime.JSValue.fromNumber(2));
    try std.testing.expectEqual(@as(i32, 1), try evalInt("target.hidden === 'h' ? 1 : 0"));

    const trapped = try Made.of("new Proxy({}, { has() { throw globalThis.boom = new Error('has'); }, set() { throw globalThis.boom2 = new Error('set'); } })");
    defer trapped.deinit();
    var proxy = try bound(trapped.handle);
    defer proxy.deinit(allocator);
    var has_body: struct {
        ctx: runtime.Context,
        argument: runtime.JSValue,
        result: protocol.Error!bool = undefined,
        fn run(self: *@This()) void {
            self.result = protocol.hasProperty(self.ctx, self.argument, "x");
        }
    } = .{ .ctx = ctx, .argument = proxy };
    const thrown = thrownBy(&has_body) orelse return error.NothingThrown;
    defer ffi.v8_Global_Dispose(thrown);
    try std.testing.expectError(error.ExceptionPending, has_body.result);
    var set_body: struct {
        ctx: runtime.Context,
        argument: runtime.JSValue,
        result: protocol.Error!void = undefined,
        fn run(self: *@This()) void {
            self.result = protocol.setProperty(self.ctx, self.argument, "x", runtime.JSValue.fromNumber(1));
        }
    } = .{ .ctx = ctx, .argument = proxy };
    const set_thrown = thrownBy(&set_body) orelse return error.NothingThrown;
    defer ffi.v8_Global_Dispose(set_thrown);
    try std.testing.expectError(error.ExceptionPending, set_body.result);
    try std.testing.expect(try holds("thrownSet", set_thrown, "thrownSet === globalThis.boom2 ? 1 : 0"));
}

test "protocol: Type and SameValue" {
    const ctx = try realm();
    const cases = [_]struct { code: []const u8, type: protocol.ValueType }{
        .{ .code = "undefined", .type = .undefined },
        .{ .code = "null", .type = .null },
        .{ .code = "true", .type = .boolean },
        .{ .code = "'s'", .type = .string },
        .{ .code = "Symbol()", .type = .symbol },
        .{ .code = "1.5", .type = .number },
        .{ .code = "1n", .type = .bigint },
        .{ .code = "(function () {})", .type = .object },
    };
    for (cases) |case| {
        const made = try Made.of(case.code);
        defer made.deinit();
        try std.testing.expectEqual(case.type, protocol.typeOf(ctx, made.value()));
    }
    try std.testing.expectEqual(protocol.ValueType.string, protocol.typeOf(ctx, runtime.JSValue.fromStringRef("x")));

    const nan = try Made.of("NaN");
    defer nan.deinit();
    const minus_zero = try Made.of("-0");
    defer minus_zero.deinit();
    const object = try Made.of("globalThis.sameObject = {}");
    defer object.deinit();
    const again = try Made.of("sameObject");
    defer again.deinit();
    const other = try Made.of("({})");
    defer other.deinit();
    const text = try Made.of("'a'");
    defer text.deinit();
    const big = try Made.of("10n");
    defer big.deinit();
    const big_again = try Made.of("10n");
    defer big_again.deinit();
    try std.testing.expect(protocol.sameValue(ctx, nan.value(), runtime.JSValue.fromNumber(std.math.nan(f64))));
    try std.testing.expect(!protocol.sameValue(ctx, minus_zero.value(), runtime.JSValue.fromNumber(0)));
    try std.testing.expect(protocol.sameValue(ctx, object.value(), again.value()));
    try std.testing.expect(!protocol.sameValue(ctx, object.value(), other.value()));
    try std.testing.expect(protocol.sameValue(ctx, text.value(), runtime.JSValue.fromStringRef("a")));
    try std.testing.expect(!protocol.sameValue(ctx, text.value(), runtime.JSValue.fromNumber(1)));
    try std.testing.expect(protocol.sameValue(ctx, big.value(), big_again.value()));
}

test "protocol: JSON bytes parse to a value, a BOM is dropped, and a SyntaxError is pending" {
    const ctx = try realm();
    _ = try evalInt("globalThis.JSON = { parse() { return 42; } }; 1");
    const parsed = try protocol.parseJsonToValue(ctx, "\xEF\xBB\xBF{\"a\":[1,2]}");
    defer parsed.release();
    try std.testing.expect(try holds("parsed", parsed.value.handle.ptr, "parsed.a.length === 2 && parsed.a[1] === 2 ? 1 : 0"));

    var body: struct {
        ctx: runtime.Context,
        result: protocol.Error!protocol.Owned = undefined,
        fn run(self: *@This()) void {
            self.result = protocol.parseJsonToValue(self.ctx, "{nope");
        }
    } = .{ .ctx = ctx };
    const thrown = thrownBy(&body) orelse return error.NothingThrown;
    defer ffi.v8_Global_Dispose(thrown);
    try std.testing.expectError(error.ExceptionPending, body.result);
    try std.testing.expect(try holds("jsonError", thrown, "jsonError instanceof SyntaxError ? 1 : 0"));
}

const Reports = struct {
    count: usize = 0,
    realm: ?protocol.Context = null,
    had_message: bool = false,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        self.realm = info.realm;
        self.had_message = std.mem.indexOf(u8, info.message, "invoked") != null;
    }
};

test "protocol: invoke a callback function - the value, a rethrown or a reported throw, and a non-callable" {
    const ctx = try realm();
    v8.context_manager.init(std.heap.page_allocator) catch {};
    const hosted = try v8.context_manager.getOrCreate(context_once.?, std.heap.page_allocator);

    const adder = try Made.of("(function (a, b) { 'use strict'; return (this === globalThis ? 100 : 0) + a + b; })");
    defer adder.deinit();
    var callback = try bound(adder.handle);
    defer callback.deinit(allocator);
    const args = [_]runtime.JSValue{ runtime.JSValue.fromNumber(1), runtime.JSValue.fromNumber(2) };

    const plain = try protocol.invokeCallbackFunction(ctx, callback, .undefined, &args, .rethrow);
    try std.testing.expectEqual(@as(i32, 3), int32Of(plain.normal));
    plain.normal.release();
    const with_global = try protocol.invokeCallbackFunction(ctx, callback, .global_this, &args, .rethrow);
    try std.testing.expectEqual(@as(i32, 103), int32Of(with_global.normal));
    with_global.normal.release();

    const thrower = try Made.of("(function () { throw globalThis.invokedError = new Error('invoked'); })");
    defer thrower.deinit();
    var throwing = try bound(thrower.handle);
    defer throwing.deinit(allocator);
    // "rethrow": the thrown value handed back, not pending.
    const rethrown = try protocol.invokeCallbackFunction(ctx, throwing, .undefined, &.{}, .rethrow);
    try std.testing.expect(rethrown == .throw);
    try std.testing.expect(try holds("rethrown", rethrown.throw.value.handle.ptr, "rethrown === globalThis.invokedError ? 1 : 0"));
    rethrown.throw.release();
    // "report": reported for the callback's realm, then undefined.
    var reports: Reports = .{};
    const reported = try protocol.invokeCallbackFunction(ctx, throwing, .undefined, &.{}, .{ .report = .{ .report = Reports.report, .host = &reports } });
    try std.testing.expect(reported == .normal);
    try std.testing.expectEqual(protocol.ValueType.undefined, protocol.typeOf(ctx, reported.normal.value));
    try std.testing.expectEqual(@as(usize, 1), reports.count);
    try std.testing.expectEqual(@as(?protocol.Context, hosted), reports.realm);
    try std.testing.expect(reports.had_message);

    // [LegacyTreatNonObjectAsNull]: not callable, not called.
    const nothing = try protocol.invokeCallbackFunction(ctx, runtime.JSValue.fromNumber(5), .undefined, &.{}, .rethrow);
    try std.testing.expectEqual(protocol.ValueType.undefined, protocol.typeOf(ctx, nothing.normal.value));
}

test "protocol: call a user object's operation - a function, a handleEvent, a throwing getter, a non-callable" {
    const ctx = try realm();
    const args = [_]runtime.JSValue{runtime.JSValue.fromNumber(5)};

    const function = try Made.of("(function (x) { return x * 2; })");
    defer function.deinit();
    var as_function = try bound(function.handle);
    defer as_function.deinit(allocator);
    const doubled = try protocol.callUserObjectOperation(ctx, as_function, "handleEvent", .undefined, &args, .rethrow);
    try std.testing.expectEqual(@as(i32, 10), int32Of(doubled.normal));
    doubled.normal.release();

    const listener = try Made.of("({ base: 1, handleEvent(x) { return this.base + x; } })");
    defer listener.deinit();
    var as_object = try bound(listener.handle);
    defer as_object.deinit(allocator);
    // thisArg is O, whatever was given.
    const called = try protocol.callUserObjectOperation(ctx, as_object, "handleEvent", .undefined, &args, .rethrow);
    try std.testing.expectEqual(@as(i32, 6), int32Of(called.normal));
    called.normal.release();

    const getter = try Made.of("({ get handleEvent() { throw globalThis.getterError = new Error('getter'); } })");
    defer getter.deinit();
    var throwing_getter = try bound(getter.handle);
    defer throwing_getter.deinit(allocator);
    const from_get = try protocol.callUserObjectOperation(ctx, throwing_getter, "handleEvent", .undefined, &.{}, .rethrow);
    try std.testing.expect(try holds("fromGet", from_get.throw.value.handle.ptr, "fromGet === globalThis.getterError ? 1 : 0"));
    from_get.throw.release();

    const not_callable = try Made.of("({ handleEvent: 5 })");
    defer not_callable.deinit();
    var five = try bound(not_callable.handle);
    defer five.deinit(allocator);
    const type_error = try protocol.callUserObjectOperation(ctx, five, "handleEvent", .undefined, &.{}, .rethrow);
    try std.testing.expect(try holds("notCallable", type_error.throw.value.handle.ptr, "notCallable instanceof TypeError ? 1 : 0"));
    type_error.throw.release();
}

const Visited = struct {
    sum: i32 = 0,
    count: usize = 0,
    fn each(data: ?*anyopaque, item: runtime.JSValue) protocol.Error!void {
        const self: *Visited = @ptrCast(@alignCast(data.?));
        self.count += 1;
        self.sum += ffi.v8_Value_Int32Value(@ptrCast(@alignCast(item.handle.ptr)), context_once.?);
    }
};

test "protocol: iterate visits every item; no @@iterator is false; a throwing iterator is pending" {
    const ctx = try realm();
    const array = try Made.of("[1, 2, 3]");
    defer array.deinit();
    var visited: Visited = .{};
    try std.testing.expect(try protocol.iterate(ctx, array.value(), Visited.each, &visited));
    try std.testing.expectEqual(@as(usize, 3), visited.count);
    try std.testing.expectEqual(@as(i32, 6), visited.sum);

    const plain = try Made.of("({})");
    defer plain.deinit();
    try std.testing.expect(!try protocol.iterate(ctx, plain.value(), Visited.each, &visited));
    try std.testing.expectError(error.TypeError, protocol.iterate(ctx, runtime.JSValue.fromNumber(1), Visited.each, &visited));

    const failing = try Made.of("({ *[Symbol.iterator]() { yield 1; throw globalThis.iterError = new Error('iter'); } })");
    defer failing.deinit();
    var body: struct {
        ctx: runtime.Context,
        value: runtime.JSValue,
        visited: Visited = .{},
        result: protocol.Error!bool = undefined,
        fn run(self: *@This()) void {
            self.result = protocol.iterate(self.ctx, self.value, Visited.each, &self.visited);
        }
    } = .{ .ctx = ctx, .value = failing.value() };
    const thrown = thrownBy(&body) orelse return error.NothingThrown;
    defer ffi.v8_Global_Dispose(thrown);
    try std.testing.expectError(error.ExceptionPending, body.result);
    try std.testing.expectEqual(@as(usize, 1), body.visited.count);
}

test "protocol: sequence<any> and a sequence of string pairs" {
    const ctx = try realm();
    const generator = try Made.of("(function* () { yield 'a'; yield 2; yield {}; })()");
    defer generator.deinit();
    const items = try protocol.convertToSequence(ctx, generator.value(), allocator);
    defer allocator.free(items);
    defer for (items) |item| item.release();
    try std.testing.expectEqual(@as(usize, 3), items.len);
    try std.testing.expectEqual(protocol.ValueType.object, protocol.typeOf(ctx, items[2].value));
    const plain = try Made.of("({})");
    defer plain.deinit();
    try std.testing.expectError(error.TypeError, protocol.convertToSequence(ctx, plain.value(), allocator));

    const pairs_value = try Made.of("[['a', 'b'], new Set(['c', 'd'])]");
    defer pairs_value.deinit();
    const entries = (try protocol.convertToSequenceOfStringPairs(ctx, pairs_value.value(), .usv_string, allocator)) orelse return error.NotASequence;
    defer runtime.StringRecordEntry.freeAll(entries, allocator);
    try std.testing.expectEqual(@as(usize, 2), entries.len);
    try std.testing.expectEqualStrings("c", entries[1].key);
    try std.testing.expectEqualStrings("d", entries[1].value);
    // Not the sequence member: a record, or a string.
    try std.testing.expect(try protocol.convertToSequenceOfStringPairs(ctx, plain.value(), .usv_string, allocator) == null);
    try std.testing.expect(try protocol.convertToSequenceOfStringPairs(ctx, runtime.JSValue.fromStringRef("a=b"), .usv_string, allocator) == null);
    const wrong_size = try Made.of("[['a']]");
    defer wrong_size.deinit();
    try std.testing.expectError(error.TypeError, protocol.convertToSequenceOfStringPairs(ctx, wrong_size.value(), .usv_string, allocator));
    // An item that is not iterable is a TypeError of its conversion.
    const not_pairs = try Made.of("[5]");
    defer not_pairs.deinit();
    try std.testing.expectError(error.TypeError, protocol.convertToSequenceOfStringPairs(ctx, not_pairs.value(), .usv_string, allocator));
}

test "protocol: iterator records - next, the result, return, and an async iterator's promise" {
    const ctx = try realm();
    const generator = try Made.of("globalThis.returned = 0; (function* () { try { yield 1; yield 2; } finally { returned++; } })()");
    defer generator.deinit();
    const record = try protocol.getIterator(ctx, generator.value(), .sync);
    defer protocol.releaseIteratorRecord(record);
    const first = try protocol.iteratorNext(ctx, record);
    defer first.release();
    const result = try protocol.iteratorResult(ctx, first.value);
    defer result.value.release();
    try std.testing.expect(!result.done);
    try std.testing.expectEqual(@as(i32, 1), int32Of(result.value));
    const closed = (try protocol.iteratorReturn(ctx, record, runtime.JSValue.fromNumber(9))) orelse return error.NoReturn;
    defer closed.release();
    const closed_result = try protocol.iteratorResult(ctx, closed.value);
    defer closed_result.value.release();
    try std.testing.expect(closed_result.done);
    try std.testing.expectEqual(@as(i32, 1), try evalInt("globalThis.returned"));

    // An array iterator has no `return`.
    const array = try Made.of("[1]");
    defer array.deinit();
    const array_record = try protocol.getIterator(ctx, array.value(), .sync);
    defer protocol.releaseIteratorRecord(array_record);
    try std.testing.expect(try protocol.iteratorReturn(ctx, array_record, runtime.JSValue.jsUndefined) == null);

    // An async iterator's next answers a promise, for the caller to await.
    const async_generator = try Made.of("(async function* () { yield 1; })()");
    defer async_generator.deinit();
    const async_record = try protocol.getIterator(ctx, async_generator.value(), .async);
    defer protocol.releaseIteratorRecord(async_record);
    const pending = try protocol.iteratorNext(ctx, async_record);
    defer pending.release();
    try std.testing.expect(ffi.v8_Value_IsPromise(@ptrCast(@alignCast(pending.value.handle.ptr))));
    // Not built yet: an async iterator over a sync iterable.
    try std.testing.expectError(error.NotSupported, protocol.getIterator(ctx, array.value(), .async));
    try std.testing.expectError(error.TypeError, protocol.getIterator(ctx, runtime.JSValue.fromNumber(1), .sync));
}

test "protocol: a frozen array" {
    const ctx = try realm();
    const values = [_]runtime.JSValue{ runtime.JSValue.fromNumber(1), runtime.JSValue.fromStringRef("two") };
    const array = try protocol.createFrozenArray(ctx, &values);
    defer array.release();
    try std.testing.expect(try holds("frozen", array.value.handle.ptr, "Array.isArray(frozen) && Object.isFrozen(frozen) && frozen[1] === 'two' ? 1 : 0"));
}

test "protocol: the values, callbacks and iteration operations leave no Global behind" {
    const ctx = try realm();
    const object = try Made.of("({ a: 1, handleEvent() { return 1; } })");
    defer object.deinit();
    const function = try Made.of("(function () { return 1; })");
    defer function.deinit();
    const iterable = try Made.of("[['a', 'b']]");
    defer iterable.deinit();
    const round = struct {
        fn run(c: runtime.Context, o: runtime.JSValue, f: runtime.JSValue, it: runtime.JSValue) !void {
            (try protocol.getProperty(c, o, "a")).release();
            try protocol.setProperty(c, o, "b", runtime.JSValue.fromNumber(2));
            try protocol.defineOwnProperty(c, o, "c", runtime.JSValue.fromNumber(3), .{ .writable = true, .enumerable = true, .configurable = true });
            _ = try protocol.hasProperty(c, o, "a");
            _ = protocol.typeOf(c, o);
            _ = protocol.sameValue(c, o, f);
            (try protocol.parseJsonToValue(c, "[1]")).release();
            (try protocol.invokeCallbackFunction(c, f, .global_this, &.{runtime.JSValue.fromNumber(1)}, .rethrow)).normal.release();
            (try protocol.callUserObjectOperation(c, o, "handleEvent", .undefined, &.{}, .rethrow)).normal.release();
            const items = try protocol.convertToSequence(c, it, allocator);
            for (items) |item| item.release();
            allocator.free(items);
            const entries = (try protocol.convertToSequenceOfStringPairs(c, it, .dom_string, allocator)).?;
            runtime.StringRecordEntry.freeAll(entries, allocator);
            const record = try protocol.getIterator(c, it, .sync);
            (try protocol.iteratorNext(c, record)).release();
            protocol.releaseIteratorRecord(record);
            (try protocol.createFrozenArray(c, &.{runtime.JSValue.fromNumber(1)})).release();
        }
    }.run;
    try round(ctx, object.value(), function.value(), iterable.value());
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate_once.?);
    for (0..32) |_| try round(ctx, object.value(), function.value(), iterable.value());
    // A leak here is a node per call: 32 rounds of over a dozen calls, more
    // than 1 KB. Measured instead: every operation alone flat over 32 rounds,
    // and the whole round taking one 32-byte node once, at a different round
    // each run, then flat for 96 - V8's own, as script the round calls tiers
    // up. Two such nodes are allowed; a per-call leak is not.
    try std.testing.expect(ffi.v8_Isolate_GetGlobalHandleBytes(isolate_once.?) <= before + 64);
}
