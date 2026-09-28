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
    data.* = try runtime.ContextData.init(std.heap.page_allocator, .{ .engine_ctx = context });
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
    const text = try v8.webidl_conversions.convertToDOMString(ctx, object.value(), allocator);
    defer allocator.free(text);
    try std.testing.expectEqualStrings("custom", text);

    const number = try v8.webidl_conversions.convertToDOMString(ctx, .{ .number = 1.5 }, allocator);
    defer allocator.free(number);
    try std.testing.expectEqualStrings("1.5", number);

    const already = try v8.webidl_conversions.convertToDOMString(ctx, runtime.JSValue.fromStringRef("as is"), allocator);
    defer allocator.free(already);
    try std.testing.expectEqualStrings("as is", already);
}

test "a Symbol is a TypeError with nothing thrown" {
    const ctx = try realm();
    const symbol = try Made.of("Symbol('s')");
    defer symbol.deinit();
    try std.testing.expectError(error.TypeError, v8.webidl_conversions.convertToDOMString(ctx, symbol.value(), allocator));
    try std.testing.expectError(error.TypeError, v8.webidl_conversions.convertToUSVString(ctx, symbol.value(), allocator));
}

test "a lone surrogate becomes U+FFFD in a USVString" {
    const ctx = try realm();
    const lone = try Made.of("'a\\uD800b'");
    defer lone.deinit();
    const usv = try v8.webidl_conversions.convertToUSVString(ctx, lone.value(), allocator);
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
    const result: f64 = if (v8.webidl_conversions.convertToDOMString(data_once.?, value, allocator)) |text| blk: {
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
    const strings = (try v8.webidl_conversions.convertToSequenceOfDOMStrings(ctx, array.value(), allocator)).?;
    defer freeStrings(strings);
    try std.testing.expectEqual(@as(usize, 3), strings.len);
    try std.testing.expectEqualStrings("a", strings[0]);
    try std.testing.expectEqualStrings("2", strings[1]);
    try std.testing.expectEqualStrings("c", strings[2]);

    const set = try Made.of("new Set(['x', 'y'])");
    defer set.deinit();
    const from_set = (try v8.webidl_conversions.convertToSequenceOfDOMStrings(ctx, set.value(), allocator)).?;
    defer freeStrings(from_set);
    try std.testing.expectEqual(@as(usize, 2), from_set.len);
}

test "an object with no @@iterator is not a sequence (null), and a non-object is a TypeError" {
    const ctx = try realm();
    const plain = try Made.of("({ length: 1, 0: 'a' })");
    defer plain.deinit();
    try std.testing.expectEqual(@as(?[][]u8, null), try v8.webidl_conversions.convertToSequenceOfDOMStrings(ctx, plain.value(), allocator));
    try std.testing.expectError(error.TypeError, v8.webidl_conversions.convertToSequenceOfDOMStrings(ctx, .{ .number = 1 }, allocator));
    // A String object IS iterable: its characters.
    const boxed = try Made.of("new String('ab')");
    defer boxed.deinit();
    const chars = (try v8.webidl_conversions.convertToSequenceOfDOMStrings(ctx, boxed.value(), allocator)).?;
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
    const record = try v8.webidl_conversions.convertToRecordOfStrings(ctx, object.value(), .usv_string, .usv_string, allocator);
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
    const none = try v8.webidl_conversions.convertToRecordOfStrings(ctx, empty.value(), .dom_string, .dom_string, allocator);
    defer freeRecord(none);
    try std.testing.expectEqual(@as(usize, 0), none.len);
}

test "USVString keys that collide after U+FFFD replacement are one entry, set in place" {
    const ctx = try realm();
    const object = try Made.of("({ '\\uD83D': 'first', z: 'z', '\\uFFFD': 'second', v: 'a\\uD800b' })");
    defer object.deinit();
    const usv = try v8.webidl_conversions.convertToRecordOfStrings(ctx, object.value(), .usv_string, .usv_string, allocator);
    defer freeRecord(usv);
    try std.testing.expectEqual(@as(usize, 3), usv.len);
    try std.testing.expectEqualStrings("\u{FFFD}", usv[0].key);
    try std.testing.expectEqualStrings("second", usv[0].value);
    try std.testing.expectEqualStrings("z", usv[1].key);
    try std.testing.expectEqualStrings("v", usv[2].key);
    try std.testing.expectEqualStrings("a\u{FFFD}b", usv[2].value);

    // As DOMStrings, the lone surrogate stays: two keys.
    const dom = try v8.webidl_conversions.convertToRecordOfStrings(ctx, object.value(), .dom_string, .dom_string, allocator);
    defer freeRecord(dom);
    try std.testing.expectEqual(@as(usize, 4), dom.len);
    try std.testing.expect(!std.mem.eql(u8, dom[0].key, dom[2].key));
}

test "a non-object, and an enumerable Symbol-keyed property, are TypeErrors" {
    const ctx = try realm();
    try std.testing.expectError(error.TypeError, v8.webidl_conversions.convertToRecordOfStrings(ctx, .{ .number = 1 }, .usv_string, .usv_string, allocator));
    try std.testing.expectError(error.TypeError, v8.webidl_conversions.convertToRecordOfStrings(ctx, runtime.JSValue.fromStringRef("a=b"), .usv_string, .usv_string, allocator));
    try std.testing.expectError(error.TypeError, v8.webidl_conversions.convertToRecordOfStrings(ctx, runtime.JSValue.jsNull, .usv_string, .usv_string, allocator));
    const symbol = try Made.of("Symbol('s')");
    defer symbol.deinit();
    try std.testing.expectError(error.TypeError, v8.webidl_conversions.convertToRecordOfStrings(ctx, symbol.value(), .usv_string, .usv_string, allocator));
    const keyed = try Made.of("({ a: '1', [Symbol('k')]: '2' })");
    defer keyed.deinit();
    try std.testing.expectError(error.TypeError, v8.webidl_conversions.convertToRecordOfStrings(ctx, keyed.value(), .usv_string, .usv_string, allocator));
    // A Symbol VALUE does not convert to a string either.
    const valued = try Made.of("({ a: Symbol('v') })");
    defer valued.deinit();
    try std.testing.expectError(error.TypeError, v8.webidl_conversions.convertToRecordOfStrings(ctx, valued.value(), .dom_string, .dom_string, allocator));
}

/// A native that converts its argument to a record<USVString, USVString> as
/// an impl does, from the binding's form of the argument, and returns its
/// entry count - or -1 for a TypeError; an ExceptionPending returns nothing.
fn recordSize(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const argument = info.get(0);
    defer ffi.v8_Global_Dispose(argument);
    var value = v8.conversions.fromV8Value(runtime.JSValue, allocator, isolate_once.?, context_once.?, argument) catch return;
    defer value.deinit(allocator);
    const result: f64 = if (v8.webidl_conversions.convertToRecordOfStrings(data_once.?, value, .usv_string, .usv_string, allocator)) |record| blk: {
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
    const all = (try v8.webidl_conversions.getCopyOfBufferSourceBytes(ctx, buffer.value(), allocator)).?;
    defer allocator.free(all);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4, 5 }, all);

    const view = try Made.of("new Uint8Array(b, 1, 3)");
    defer view.deinit();
    const window = (try v8.webidl_conversions.getCopyOfBufferSourceBytes(ctx, view.value(), allocator)).?;
    defer allocator.free(window);
    try std.testing.expectEqualSlices(u8, &.{ 2, 3, 4 }, window);

    const data_view = try Made.of("new DataView(b, 3)");
    defer data_view.deinit();
    const tail = (try v8.webidl_conversions.getCopyOfBufferSourceBytes(ctx, data_view.value(), allocator)).?;
    defer allocator.free(tail);
    try std.testing.expectEqualSlices(u8, &.{ 4, 5 }, tail);
}

test "a detached buffer holds no bytes, and neither does a view of one" {
    const ctx = try realm();
    const detached = try Made.of("globalThis.d = new ArrayBuffer(8); globalThis.dv = new Uint8Array(d); d.transfer(); d");
    defer detached.deinit();
    const none = (try v8.webidl_conversions.getCopyOfBufferSourceBytes(ctx, detached.value(), allocator)).?;
    defer allocator.free(none);
    try std.testing.expectEqual(@as(usize, 0), none.len);
    const view = try Made.of("dv");
    defer view.deinit();
    const view_none = (try v8.webidl_conversions.getCopyOfBufferSourceBytes(ctx, view.value(), allocator)).?;
    defer allocator.free(view_none);
    try std.testing.expectEqual(@as(usize, 0), view_none.len);
}

test "a SharedArrayBuffer is not a BufferSource, and a view of one is a TypeError" {
    const ctx = try realm();
    const shared = try Made.of("globalThis.sab = new SharedArrayBuffer(4); sab");
    defer shared.deinit();
    try std.testing.expectEqual(@as(?[]u8, null), try v8.webidl_conversions.getCopyOfBufferSourceBytes(ctx, shared.value(), allocator));
    const view = try Made.of("new Uint8Array(sab)");
    defer view.deinit();
    try std.testing.expectError(error.TypeError, v8.webidl_conversions.getCopyOfBufferSourceBytes(ctx, view.value(), allocator));
}

test "anything else is not a BufferSource" {
    const ctx = try realm();
    const object = try Made.of("({})");
    defer object.deinit();
    try std.testing.expectEqual(@as(?[]u8, null), try v8.webidl_conversions.getCopyOfBufferSourceBytes(ctx, object.value(), allocator));
    try std.testing.expectEqual(@as(?[]u8, null), try v8.webidl_conversions.getCopyOfBufferSourceBytes(ctx, .{ .number = 3 }, allocator));
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

    try std.testing.expectEqual(@as(?*runtime.Instance, &mock_blob), v8.webidl_conversions.convertToPlatformObject(ctx, asValue(@ptrCast(object))));
    const plain = try Made.of("({})");
    defer plain.deinit();
    try std.testing.expectEqual(@as(?*runtime.Instance, null), v8.webidl_conversions.convertToPlatformObject(ctx, plain.value()));
    const function = try Made.of("(function () {})");
    defer function.deinit();
    try std.testing.expectEqual(@as(?*runtime.Instance, null), v8.webidl_conversions.convertToPlatformObject(ctx, function.value()));
    try std.testing.expectEqual(@as(?*runtime.Instance, null), v8.webidl_conversions.convertToPlatformObject(ctx, .{ .number = 1 }));
}

test "a sequence of values becomes an Array of the realm" {
    const ctx = try realm();
    const object = try Made.of("globalThis.o = {}; o");
    defer object.deinit();
    const array = try v8.webidl_conversions.createSequenceOfValues(ctx, &.{ .{ .number = 7 }, runtime.JSValue.fromStringRef("s"), object.value() });
    defer v8.engine.v8ReleaseValue(array);
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

/// A callback function value over a value the test keeps (BORROWED into the
/// tuple: nothing here releases it), with `context` as its callback context.
fn callbackFunction(value: runtime.JSValue, context: ?runtime.Context) protocol.CallbackFunction {
    return .{ .function = .{ .value = value }, .context = context };
}

/// A callback interface value, as callbackFunction.
fn callbackInterface(value: runtime.JSValue, context: ?runtime.Context) protocol.CallbackInterface {
    return .{ .object = .{ .value = value }, .context = context };
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

/// serializeJsonToBytes of `value` in `ctx`, run under a TryCatch: the
/// result, and what was thrown (OWNED, or null).
const Serialized = struct {
    ctx: runtime.Context,
    value: runtime.JSValue,
    result: protocol.Error![]u8 = undefined,
    thrown: ?*ffi.Value = null,

    fn of(ctx: runtime.Context, value: runtime.JSValue) Serialized {
        var self: Serialized = .{ .ctx = ctx, .value = value };
        self.thrown = thrownBy(&self);
        return self;
    }

    fn run(self: *Serialized) void {
        self.result = protocol.serializeJsonToBytes(self.ctx, self.value, std.testing.allocator);
    }

    fn deinit(self: Serialized) void {
        if (self.result) |bytes| std.testing.allocator.free(bytes) else |_| {}
        if (self.thrown) |t| ffi.v8_Global_Dispose(t);
    }

    fn expectBytes(self: Serialized, expected: []const u8) !void {
        try std.testing.expect(self.thrown == null);
        try std.testing.expectEqualStrings(expected, try self.result);
    }
};

test "protocol: a value serializes to JSON bytes through %JSON.stringify%, as UTF-8" {
    const ctx = try realm();
    // The intrinsic, whatever script did to the global JSON.
    _ = try evalInt("globalThis.JSON = { stringify() { return '\"replaced\"'; } }; 1");

    const text = Serialized.of(ctx, runtime.JSValue.fromStringRef("hello world"));
    defer text.deinit();
    try text.expectBytes("\"hello world\"");

    const object = try Made.of("({ foo: 'bar', n: [1, null], skip: undefined })");
    defer object.deinit();
    const serialized = Serialized.of(ctx, object.value());
    defer serialized.deinit();
    try serialized.expectBytes("{\"foo\":\"bar\",\"n\":[1,null]}");

    // UTF-8 encode: a supplementary character is four bytes; a lone
    // surrogate never reaches it - JSON.stringify escapes one.
    const astral = try Made.of("'\\u{1D306}'");
    defer astral.deinit();
    const astral_bytes = Serialized.of(ctx, astral.value());
    defer astral_bytes.deinit();
    try astral_bytes.expectBytes("\"\xF0\x9D\x8C\x86\"");
    const lone = try Made.of("'\\uDF06\\uD834'");
    defer lone.deinit();
    const lone_bytes = Serialized.of(ctx, lone.value());
    defer lone_bytes.deinit();
    try lone_bytes.expectBytes("\"\\udf06\\ud834\"");
}

test "protocol: no JSON representation is a TypeError, and what the serializer throws is pending" {
    const ctx = try realm();
    // 2. JSON.stringify returned undefined: the caller throws a TypeError,
    //    nothing is thrown yet.
    const nothing = Serialized.of(ctx, .undefined);
    defer nothing.deinit();
    try std.testing.expectError(error.TypeError, nothing.result);
    try std.testing.expect(nothing.thrown == null);
    const symbol = try Made.of("Symbol('foo')");
    defer symbol.deinit();
    const from_symbol = Serialized.of(ctx, symbol.value());
    defer from_symbol.deinit();
    try std.testing.expectError(error.TypeError, from_symbol.result);
    try std.testing.expect(from_symbol.thrown == null);
    const function = try Made.of("(function () {})");
    defer function.deinit();
    const from_function = Serialized.of(ctx, function.value());
    defer from_function.deinit();
    try std.testing.expectError(error.TypeError, from_function.result);

    // 1. "? Call": a cycle's TypeError and a getter's own exception propagate.
    const cycle = try Made.of("(() => { const a = { b: 1 }; a.a = a; return a; })()");
    defer cycle.deinit();
    const from_cycle = Serialized.of(ctx, cycle.value());
    defer from_cycle.deinit();
    try std.testing.expectError(error.ExceptionPending, from_cycle.result);
    try std.testing.expect(try holds("cycleError", from_cycle.thrown orelse return error.NothingThrown, "cycleError instanceof TypeError ? 1 : 0"));
    const getter = try Made.of("({ get foo() { throw globalThis.fromGetter = new RangeError('bar'); } })");
    defer getter.deinit();
    const from_getter = Serialized.of(ctx, getter.value());
    defer from_getter.deinit();
    try std.testing.expectError(error.ExceptionPending, from_getter.result);
    try std.testing.expect(try holds("getterError", from_getter.thrown orelse return error.NothingThrown, "getterError === globalThis.fromGetter ? 1 : 0"));
}

test "protocol: serializing to JSON bytes leaves no Global behind" {
    const ctx = try realm();
    const object = try Made.of("({ a: [1, 2, { b: 'c' }] })");
    defer object.deinit();
    const round = struct {
        fn run(c: runtime.Context, value: runtime.JSValue) !void {
            std.testing.allocator.free(try protocol.serializeJsonToBytes(c, value, std.testing.allocator));
            try std.testing.expectError(error.TypeError, protocol.serializeJsonToBytes(c, .undefined, std.testing.allocator));
        }
    }.run;
    try round(ctx, object.value());
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate_once.?);
    for (0..32) |_| try round(ctx, object.value());
    try std.testing.expect(ffi.v8_Isolate_GetGlobalHandleBytes(isolate_once.?) <= before);
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

    const plain = try protocol.invokeCallbackFunction(ctx, &callbackFunction(callback, ctx), .undefined, &args, .rethrow);
    try std.testing.expectEqual(@as(i32, 3), int32Of(plain.normal));
    plain.normal.release();
    const with_global = try protocol.invokeCallbackFunction(ctx, &callbackFunction(callback, ctx), .global_this, &args, .rethrow);
    try std.testing.expectEqual(@as(i32, 103), int32Of(with_global.normal));
    with_global.normal.release();

    const thrower = try Made.of("(function () { throw globalThis.invokedError = new Error('invoked'); })");
    defer thrower.deinit();
    var throwing = try bound(thrower.handle);
    defer throwing.deinit(allocator);
    // "rethrow": the thrown value handed back, not pending.
    const rethrown = try protocol.invokeCallbackFunction(ctx, &callbackFunction(throwing, ctx), .undefined, &.{}, .rethrow);
    try std.testing.expect(rethrown == .throw);
    try std.testing.expect(try holds("rethrown", rethrown.throw.value.handle.ptr, "rethrown === globalThis.invokedError ? 1 : 0"));
    rethrown.throw.release();
    // "report": reported for the callback's realm, then undefined.
    var reports: Reports = .{};
    const reported = try protocol.invokeCallbackFunction(ctx, &callbackFunction(throwing, ctx), .undefined, &.{}, .{ .report = .{ .report = Reports.report, .host = &reports } });
    try std.testing.expect(reported == .normal);
    try std.testing.expectEqual(protocol.ValueType.undefined, protocol.typeOf(ctx, reported.normal.value));
    try std.testing.expectEqual(@as(usize, 1), reports.count);
    try std.testing.expectEqual(@as(?protocol.Context, hosted), reports.realm);
    try std.testing.expect(reports.had_message);

    // [LegacyTreatNonObjectAsNull]: not callable, not called.
    const nothing = try protocol.invokeCallbackFunction(ctx, &callbackFunction(runtime.JSValue.fromNumber(5), ctx), .undefined, &.{}, .rethrow);
    try std.testing.expectEqual(protocol.ValueType.undefined, protocol.typeOf(ctx, nothing.normal.value));
}

/// A value made by `code` compiled as the script at `url`, and the Global to
/// dispose.
fn evalAt(code: []const u8, url: []const u8) !*ffi.Value {
    const context = context_once.?;
    const text = ffi.v8_String_NewFromUtf8(isolate_once.?, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const name = ffi.v8_String_NewFromUtf8(isolate_once.?, url.ptr, @intCast(url.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(name);
    const script = ffi.v8_Script_CompileWithOrigin(context, text, name) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse error.RunFailed;
}

/// What a Reporter was handed: where the exception was thrown.
const Located = struct {
    count: usize = 0,
    filename: [64]u8 = undefined,
    filename_len: usize = 0,
    lineno: u32 = 0,
    colno: u32 = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Located = @ptrCast(@alignCast(host.?));
        self.count += 1;
        self.filename_len = @min(info.filename.len, self.filename.len);
        @memcpy(self.filename[0..self.filename_len], info.filename[0..self.filename_len]);
        self.lineno = info.lineno;
        self.colno = info.colno;
    }

    fn file(self: *const Located) []const u8 {
        return self.filename[0..self.filename_len];
    }

    fn behavior(self: *Located) protocol.ExceptionBehavior {
        return .{ .report = .{ .report = report, .host = self } };
    }
};

test "protocol: a reported exception is located where it was thrown, a thrown value that is not an Error too" {
    const ctx = try realm();
    const url = "https://crane.test/thrower.js";
    // HTML "extract error information" is the throw site's: a thrown string
    // carries no stack, so after the call has returned nothing else knows it.
    const thrower = try evalAt("(function () {\n  throw 'not an Error';\n})", url);
    defer ffi.v8_Value_Dispose(thrower);
    var throwing = try bound(thrower);
    defer throwing.deinit(allocator);
    var from_call: Located = .{};
    _ = try protocol.invokeCallbackFunction(ctx, &callbackFunction(throwing, ctx), .undefined, &.{}, from_call.behavior());
    try std.testing.expectEqual(@as(usize, 1), from_call.count);
    try std.testing.expectEqualStrings(url, from_call.file());
    try std.testing.expectEqual(@as(u32, 2), from_call.lineno);
    try std.testing.expect(from_call.colno > 0);

    // A user object's operation, and a getter of one that throws.
    const listener = try evalAt("({\n  acceptNode() {\n    throw 1;\n  },\n  get handleEvent() {\n    throw 2;\n  },\n})", url);
    defer ffi.v8_Value_Dispose(listener);
    var object = try bound(listener);
    defer object.deinit(allocator);
    var from_operation: Located = .{};
    _ = try protocol.callUserObjectOperation(ctx, &callbackInterface(object, ctx), "acceptNode", .undefined, &.{}, from_operation.behavior());
    try std.testing.expectEqualStrings(url, from_operation.file());
    try std.testing.expectEqual(@as(u32, 3), from_operation.lineno);
    var from_getter: Located = .{};
    _ = try protocol.callUserObjectOperation(ctx, &callbackInterface(object, ctx), "handleEvent", .undefined, &.{}, from_getter.behavior());
    try std.testing.expectEqualStrings(url, from_getter.file());
    try std.testing.expectEqual(@as(u32, 6), from_getter.lineno);

    // Reported or rethrown, what the call caught of the throw site is freed.
    const round = struct {
        fn run(c: runtime.Context, f: runtime.JSValue, o: runtime.JSValue) !void {
            var located: Located = .{};
            _ = try protocol.invokeCallbackFunction(c, &callbackFunction(f, c), .undefined, &.{}, located.behavior());
            (try protocol.invokeCallbackFunction(c, &callbackFunction(f, c), .undefined, &.{}, .rethrow)).throw.release();
            _ = try protocol.callUserObjectOperation(c, &callbackInterface(o, c), "handleEvent", .undefined, &.{}, located.behavior());
            (try protocol.callUserObjectOperation(c, &callbackInterface(o, c), "acceptNode", .undefined, &.{}, .rethrow)).throw.release();
        }
    }.run;
    try round(ctx, throwing, object);
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate_once.?);
    for (0..32) |_| try round(ctx, throwing, object);
    try std.testing.expect(ffi.v8_Isolate_GetGlobalHandleBytes(isolate_once.?) <= before + 64);
}

test "protocol: call a user object's operation - a function, a handleEvent, a throwing getter, a non-callable" {
    const ctx = try realm();
    const args = [_]runtime.JSValue{runtime.JSValue.fromNumber(5)};

    const function = try Made.of("(function (x) { return x * 2; })");
    defer function.deinit();
    var as_function = try bound(function.handle);
    defer as_function.deinit(allocator);
    const doubled = try protocol.callUserObjectOperation(ctx, &callbackInterface(as_function, ctx), "handleEvent", .undefined, &args, .rethrow);
    try std.testing.expectEqual(@as(i32, 10), int32Of(doubled.normal));
    doubled.normal.release();

    const listener = try Made.of("({ base: 1, handleEvent(x) { return this.base + x; } })");
    defer listener.deinit();
    var as_object = try bound(listener.handle);
    defer as_object.deinit(allocator);
    // thisArg is O, whatever was given.
    const called = try protocol.callUserObjectOperation(ctx, &callbackInterface(as_object, ctx), "handleEvent", .undefined, &args, .rethrow);
    try std.testing.expectEqual(@as(i32, 6), int32Of(called.normal));
    called.normal.release();

    const getter = try Made.of("({ get handleEvent() { throw globalThis.getterError = new Error('getter'); } })");
    defer getter.deinit();
    var throwing_getter = try bound(getter.handle);
    defer throwing_getter.deinit(allocator);
    const from_get = try protocol.callUserObjectOperation(ctx, &callbackInterface(throwing_getter, ctx), "handleEvent", .undefined, &.{}, .rethrow);
    try std.testing.expect(try holds("fromGet", from_get.throw.value.handle.ptr, "fromGet === globalThis.getterError ? 1 : 0"));
    from_get.throw.release();

    const not_callable = try Made.of("({ handleEvent: 5 })");
    defer not_callable.deinit();
    var five = try bound(not_callable.handle);
    defer five.deinit(allocator);
    const type_error = try protocol.callUserObjectOperation(ctx, &callbackInterface(five, ctx), "handleEvent", .undefined, &.{}, .rethrow);
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
    try std.testing.expectError(error.TypeError, protocol.getIterator(ctx, runtime.JSValue.fromNumber(1), .sync));
}

/// The code points an iterator record yields, joined by "|".
fn yieldedCodePoints(ctx: runtime.Context, record: *protocol.IteratorRecord, buffer: []u8) ![]const u8 {
    var length: usize = 0;
    while (true) {
        const next = try protocol.iteratorNext(ctx, record);
        defer next.release();
        const result = try protocol.iteratorResult(ctx, next.value);
        defer result.value.release();
        if (result.done) return buffer[0..length];
        const text = try protocol.convertToDOMString(ctx, result.value.value, allocator);
        defer allocator.free(text);
        if (length > 0) {
            buffer[length] = '|';
            length += 1;
        }
        @memcpy(buffer[length..][0..text.len], text);
        length += text.len;
    }
}

test "protocol: GetIterator of a primitive is its object's iterator - a string's code points; undefined and null are TypeErrors" {
    const ctx = try realm();
    var buffer: [64]u8 = undefined;
    // GetMethod's GetV does ToObject: "a\u{1F600}b" iterates by code point
    // (String.prototype[@@iterator]), as ReadableStream.from("...") does.
    const record = try protocol.getIterator(ctx, runtime.JSValue.fromStringRef("a\u{1F600}b"), .sync);
    defer protocol.releaseIteratorRecord(record);
    try std.testing.expectEqualStrings("a|\u{1F600}|b", try yieldedCodePoints(ctx, record, &buffer));

    // A string as an engine value, the same.
    const handle = try Made.of("'xy'");
    defer handle.deinit();
    const handle_record = try protocol.getIterator(ctx, handle.value(), .sync);
    defer protocol.releaseIteratorRecord(handle_record);
    try std.testing.expectEqualStrings("x|y", try yieldedCodePoints(ctx, handle_record, &buffer));

    // async: a string has no @@asyncIterator, so its sync iterator, awaited.
    const async_record = try protocol.getIterator(ctx, runtime.JSValue.fromStringRef("z"), .async);
    defer protocol.releaseIteratorRecord(async_record);
    const first = try settledResult(ctx, try protocol.iteratorNext(ctx, async_record));
    defer first.value.release();
    try std.testing.expect(!first.done);
    const z = try protocol.convertToDOMString(ctx, first.value.value, allocator);
    defer allocator.free(z);
    try std.testing.expectEqualStrings("z", z);

    // ToObject of undefined or null throws a TypeError; a number is an
    // object with no @@iterator - the TypeError of GetIterator's step 3.
    try std.testing.expectError(error.TypeError, protocol.getIterator(ctx, runtime.JSValue.jsUndefined, .sync));
    try std.testing.expectError(error.TypeError, protocol.getIterator(ctx, runtime.JSValue.jsNull, .async));
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
            (try protocol.invokeCallbackFunction(c, &callbackFunction(f, c), .global_this, &.{runtime.JSValue.fromNumber(1)}, .rethrow)).normal.release();
            (try protocol.callUserObjectOperation(c, &callbackInterface(o, c), "handleEvent", .undefined, &.{}, .rethrow)).normal.release();
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

// ----------------------------------------------------------------------------
// Callback contexts: the incumbent (decisions 9-10)
// ----------------------------------------------------------------------------

var other_context: ?*ffi.Context = null;

/// The realm the context manager hosts for this file's context.
fn hostedRealm() !runtime.Context {
    _ = try realm();
    v8.context_manager.init(std.heap.page_allocator) catch {};
    return v8.context_manager.getOrCreate(context_once.?, std.heap.page_allocator);
}

/// A second realm of the same agent, hosted.
fn otherRealm() !runtime.Context {
    _ = try hostedRealm();
    if (other_context == null) other_context = ffi.v8_Context_New(isolate_once.?) orelse return error.ContextCreationFailed;
    return v8.context_manager.getOrCreate(other_context.?, std.heap.page_allocator);
}

var recorded_incumbent: ?runtime.Context = null;

/// A built-in function: records HTML's incumbent realm when called.
fn recordIncumbent(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const context = ffi.v8_Isolate_GetIncumbentContext(info.getIsolate()) orelse return;
    defer ffi.v8_Context_Dispose(context);
    recorded_incumbent = v8.context_manager.get(context);
}

test "protocol: prepare to run a callback makes the callback context the incumbent" {
    const ctx = try realm();
    const here = try hostedRealm();
    const other = try otherRealm();
    try installNative("recordIncumbent", recordIncumbent);
    const native = try Made.of("recordIncumbent");
    defer native.deinit();

    // A built-in callback has no script frame: the incumbent is the callback
    // context, whichever realm that is.
    recorded_incumbent = null;
    (try protocol.invokeCallbackFunction(ctx, &callbackFunction(native.value(), other), .undefined, &.{}, .rethrow)).normal.release();
    try std.testing.expectEqual(@as(?runtime.Context, other), recorded_incumbent);
    (try protocol.invokeCallbackFunction(ctx, &callbackFunction(native.value(), here), .undefined, &.{}, .rethrow)).normal.release();
    try std.testing.expectEqual(@as(?runtime.Context, here), recorded_incumbent);

    // A script function is its own incumbent: its frame is newer than the
    // backup entry.
    const script_function = try Made.of("(function () { recordIncumbent(); })");
    defer script_function.deinit();
    (try protocol.invokeCallbackFunction(ctx, &callbackFunction(script_function.value(), other), .undefined, &.{}, .rethrow)).normal.release();
    try std.testing.expectEqual(@as(?runtime.Context, here), recorded_incumbent);

    // Call a user object's operation: the same, around the Get and the call.
    const listener = try Made.of("({ handleEvent: recordIncumbent })");
    defer listener.deinit();
    (try protocol.callUserObjectOperation(ctx, &callbackInterface(listener.value(), other), "handleEvent", .undefined, &.{}, .rethrow)).normal.release();
    try std.testing.expectEqual(@as(?runtime.Context, other), recorded_incumbent);
}

var taken: ?protocol.CallbackFunction = null;

/// A binding taking a callback-function argument: the conversion's Global,
/// tagged as the binding tags it, handed to takeCallbackFunction.
fn takeArgument(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const argument = info.get(0);
    taken = protocol.takeCallbackFunction(v8.pointer_tag.tagPointer(@ptrCast(argument), .global_handle));
}

test "protocol: a taken callback function or interface records the incumbent realm as its context" {
    const ctx = try realm();
    const here = try hostedRealm();
    try installNative("takeArgument", takeArgument);
    try std.testing.expectEqual(@as(i32, 1), try evalInt("takeArgument(function (x) { return x + 1; }); 1"));
    const function = taken orelse return error.NothingTaken;
    defer function.release();
    try std.testing.expectEqual(@as(?runtime.Context, here), function.context);
    const called = try protocol.invokeCallbackFunction(ctx, &function, .undefined, &.{runtime.JSValue.fromNumber(2)}, .rethrow);
    defer called.normal.release();
    try std.testing.expectEqual(@as(i32, 3), int32Of(called.normal));

    // A callback interface value as the binding converts it (a
    // runtime.CallbackWrapper), taken; the wrapper stays its holder's.
    const listener = try Made.of("({ handleEvent(x) { return x * 3; } })");
    defer listener.deinit();
    // The conversion takes the Global it is given (the binding's argument
    // handle): hand it one of its own.
    const argument = ffi.v8_Global_Clone(listener.handle) orelse return error.CloneFailed;
    const wrapper = try v8.conversions.fromV8Value(*runtime.CallbackWrapper, allocator, isolate_once.?, context_once.?, argument);
    defer {
        wrapper.deinit();
        wrapper.allocator.destroy(wrapper);
    }
    const interface = protocol.takeCallbackInterface(wrapper);
    defer interface.release();
    try std.testing.expectEqual(@as(?runtime.Context, here), interface.context);
    const result = try protocol.callUserObjectOperation(ctx, &interface, "handleEvent", .undefined, &.{runtime.JSValue.fromNumber(2)}, .rethrow);
    defer result.normal.release();
    try std.testing.expectEqual(@as(i32, 6), int32Of(result.normal));
}

// ----------------------------------------------------------------------------
// Asynchronous iterator objects, and async iteration over a sync iterable
// ----------------------------------------------------------------------------

/// Host steps for an asynchronous iterator: 1, 2, then end of iteration.
const Counter = struct {
    ctx: runtime.Context,
    next_value: i32 = 1,
    last: i32 = 2,
    returned: usize = 0,
    finalized: usize = 0,

    fn next(data: ?*anyopaque) protocol.Error!protocol.Owned {
        const self: *Counter = @ptrCast(@alignCast(data.?));
        const done = self.next_value > self.last;
        const members = [_]runtime.DictionaryMember{
            .{ .name = "value", .value = if (done) runtime.JSValue.jsUndefined else runtime.JSValue.fromNumber(@floatFromInt(self.next_value)) },
            .{ .name = "done", .value = runtime.JSValue.fromBoolean(done) },
        };
        if (!done) self.next_value += 1;
        const result = try protocol.createDictionaryObject(self.ctx, &members);
        defer result.release();
        return protocol.createResolvedPromise(self.ctx, result.value);
    }

    fn returnSteps(data: ?*anyopaque, _: runtime.JSValue) protocol.Error!protocol.Owned {
        const self: *Counter = @ptrCast(@alignCast(data.?));
        self.returned += 1;
        return protocol.createResolvedPromise(self.ctx, runtime.JSValue.jsUndefined);
    }

    fn finalize(data: ?*anyopaque) void {
        const self: *Counter = @ptrCast(@alignCast(data.?));
        self.finalized += 1;
    }

    const steps: protocol.AsyncIteratorSteps = .{ .next = next, .@"return" = returnSteps };
    const steps_finalized: protocol.AsyncIteratorSteps = .{ .next = next, .@"return" = returnSteps, .finalize = finalize };
};

test "protocol: an asynchronous iterator object - its own @@asyncIterator, queued next calls, end of iteration, return, and this" {
    const ctx = try realm();
    var counter: Counter = .{ .ctx = ctx };
    const iterator = try protocol.createAsyncIterator(ctx, &Counter.steps, &counter);
    defer iterator.release();
    try setGlobal("asyncIt", iterator.value.handle.ptr);
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\globalThis.out = []; globalThis.checks = 0;
        \\(async () => {
        \\  checks += asyncIt[Symbol.asyncIterator]() === asyncIt ? 1 : 0;
        \\  const first = asyncIt.next(), second = asyncIt.next();
        \\  const [a, b] = await Promise.all([first, second]);
        \\  out.push(a.value, b.value, a.done, b.done);
        \\  const end = await asyncIt.next(); out.push(end.done, end.value);
        \\  out.push((await asyncIt.next()).done);
        \\  const r = await asyncIt.return(9); out.push(r.value, r.done);
        \\  try { await Object.getPrototypeOf(asyncIt).next.call({}); } catch (e) { checks += e instanceof TypeError ? 1 : 0; }
        \\})();
        \\1
    ));
    ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate_once.?);
    try std.testing.expectEqual(@as(i32, 1), try evalInt("out.join() === '1,2,false,false,true,,true,9,true' && checks === 2 ? 1 : 0"));
    // Finished before return: the host's return is not run.
    try std.testing.expectEqual(@as(usize, 0), counter.returned);

    var early: Counter = .{ .ctx = ctx };
    const second = try protocol.createAsyncIterator(ctx, &Counter.steps, &early);
    defer second.release();
    try setGlobal("earlyIt", second.value.handle.ptr);
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\globalThis.seen = [];
        \\(async () => { for await (const v of earlyIt) { seen.push(v); break; } seen.push((await earlyIt.next()).done); })();
        \\1
    ));
    ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate_once.?);
    // for await's break calls return: the host's return runs, and then the
    // iterator is finished.
    try std.testing.expectEqual(@as(i32, 1), try evalInt("seen.join() === '1,true' ? 1 : 0"));
    try std.testing.expectEqual(@as(usize, 1), early.returned);
}

/// Static: the finalizer may run in any later collection, after this test.
var finalized_counter: Counter = undefined;

test "protocol: an asynchronous iterator's finalize runs when it is collected" {
    const ctx = try realm();
    finalized_counter = .{ .ctx = ctx };
    (try protocol.createAsyncIterator(ctx, &Counter.steps_finalized, &finalized_counter)).release();
    for (0..5) |_| {
        ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate_once.?);
        ffi.v8_Isolate_RequestGarbageCollection(isolate_once.?);
        if (finalized_counter.finalized == 1) break;
    }
    try std.testing.expectEqual(@as(usize, 1), finalized_counter.finalized);
}

/// The settled value of an Owned promise, once the microtasks ran, as an
/// iterator result. Releases the promise.
fn settledResult(ctx: runtime.Context, promise: protocol.Owned) !protocol.IteratorResult {
    defer promise.release();
    ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate_once.?);
    const handle: *ffi.Promise = @ptrCast(@alignCast(promise.value.handle.ptr));
    if (ffi.v8_Promise_State(handle) != 1) return error.NotFulfilled;
    const value = ffi.v8_Promise_Result(handle) orelse return error.NoResult;
    defer ffi.v8_Value_Dispose(value);
    return protocol.iteratorResult(ctx, asValue(value));
}

test "protocol: an async iterator over a sync iterable awaits each value, returns, and closes the iterator on a rejection" {
    const ctx = try realm();
    const values = try Made.of("[1, Promise.resolve(2)]");
    defer values.deinit();
    const record = try protocol.getIterator(ctx, values.value(), .async);
    defer protocol.releaseIteratorRecord(record);
    const first = try settledResult(ctx, try protocol.iteratorNext(ctx, record));
    defer first.value.release();
    try std.testing.expect(!first.done);
    try std.testing.expectEqual(@as(i32, 1), int32Of(first.value));
    // A promise value is awaited: the result carries 2, not the promise.
    const second = try settledResult(ctx, try protocol.iteratorNext(ctx, record));
    defer second.value.release();
    try std.testing.expectEqual(@as(i32, 2), int32Of(second.value));
    const third = try settledResult(ctx, try protocol.iteratorNext(ctx, record));
    defer third.value.release();
    try std.testing.expect(third.done);
    // An array iterator has no return: the async-from-sync one answers
    // { value, done: true }.
    const returned = try settledResult(ctx, (try protocol.iteratorReturn(ctx, record, runtime.JSValue.fromNumber(7))) orelse return error.NoReturn);
    defer returned.value.release();
    try std.testing.expect(returned.done);
    try std.testing.expectEqual(@as(i32, 7), int32Of(returned.value));

    // A rejected value rejects next, and closes the sync iterator.
    const generator = try Made.of("globalThis.closed = 0; (function* () { try { yield Promise.reject(new Error('x')); } finally { closed = 1; } })()");
    defer generator.deinit();
    const rejecting = try protocol.getIterator(ctx, generator.value(), .async);
    defer protocol.releaseIteratorRecord(rejecting);
    const pending = try protocol.iteratorNext(ctx, rejecting);
    defer pending.release();
    ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate_once.?);
    try std.testing.expectEqual(@as(c_int, 2), ffi.v8_Promise_State(@ptrCast(@alignCast(pending.value.handle.ptr))));
    try std.testing.expectEqual(@as(i32, 1), try evalInt("closed"));
}

test "protocol: callback contexts, asynchronous iterators and async-from-sync leave no Global behind" {
    const ctx = try realm();
    const other = try otherRealm();
    try installNative("recordIncumbent", recordIncumbent);
    const native = try Made.of("recordIncumbent");
    defer native.deinit();
    const values = try Made.of("[1, Promise.resolve(2)]");
    defer values.deinit();
    const round = struct {
        fn run(c: runtime.Context, o: runtime.Context, n: runtime.JSValue, v: runtime.JSValue) !void {
            (try protocol.invokeCallbackFunction(c, &callbackFunction(n, o), .undefined, &.{}, .rethrow)).normal.release();
            var counter: Counter = .{ .ctx = c };
            const iterator = try protocol.createAsyncIterator(c, &Counter.steps, &counter);
            const next = try protocol.getProperty(c, iterator.value, "next");
            const called = try protocol.invokeCallbackFunction(c, &callbackFunction(next.value, c), .{ .value = iterator.value }, &.{}, .rethrow);
            called.normal.release();
            next.release();
            iterator.release();
            const record = try protocol.getIterator(c, v, .async);
            (try protocol.iteratorNext(c, record)).release();
            protocol.releaseIteratorRecord(record);
            try protocol.performMicrotaskCheckpoint(c.agent.?);
        }
    }.run;
    try round(ctx, other, native.value(), values.value());
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate_once.?);
    for (0..32) |_| try round(ctx, other, native.value(), values.value());
    // As the area-2 leak check: two one-time nodes allowed, never one per call.
    try std.testing.expect(ffi.v8_Isolate_GetGlobalHandleBytes(isolate_once.?) <= before + 64);
}

// ----------------------------------------------------------------------------
// The relevant-realm rule: a platform object converts to ITS wrapper
// ----------------------------------------------------------------------------

const relevant_methods: u8 = 0;
/// An interface with no template: a realm that has not wrapped the object
/// cannot make it a wrapper, so only the wrapper its own realm made is found.
const relevant_vtable = runtime.VTable{ .name = "MockRelevantRealm", .deinit = null, .methods_ptr = &relevant_methods };
var relevant_state: u64 = 0;

/// Returns its argument.
fn identityFunction() !Made {
    return Made.of("(function (x) { return x; })");
}

test "protocol: a platform object converts to its wrapper in its relevant realm, whichever realm the operation entered" {
    const ctx = try realm();
    const here = try hostedRealm();
    const other = try otherRealm();
    _ = runtime.SlabAllocator.tryGet() catch runtime.SlabAllocator.init(std.heap.page_allocator);

    // A platform object of `other` (its relevant realm), wrapped there: a
    // plain object of `other`'s, in `other`'s wrapper cache.
    const instance = try runtime.SlabAllocator.get().alloc(&relevant_vtable);
    instance.state = @ptrCast(&relevant_state);
    instance.ctx = other;
    ffi.v8_Context_Enter(other_context.?);
    const wrapper = ffi.v8_Object_New(isolate_once.?) orelse return error.ObjectFailed;
    ffi.v8_Context_Exit(other_context.?);
    // The script's own handle keeps it alive; the cache's is weak.
    const ours = ffi.v8_Global_Clone(@ptrCast(wrapper)) orelse return error.CloneFailed;
    defer ffi.v8_Global_Dispose(ours);
    const cache: *v8.WrapperCache = @ptrCast(@alignCast(other.getV8WrapperCacheStorage().?));
    try cache.set(instance, wrapper, isolate_once.?);
    const expected = asValue(ours);
    const platform_object: runtime.JSValue = .{ .instance = instance };

    // Every operation entered in `here` hands back `other`'s wrapper.
    const held = try protocol.retainValue(here, platform_object);
    defer held.release();
    try std.testing.expect(protocol.sameValue(ctx, held.value, expected));

    const sequence = try protocol.createSequenceOfValues(here, &.{platform_object});
    defer sequence.release();
    const item = try protocol.getProperty(here, sequence.value, "0");
    defer item.release();
    try std.testing.expect(protocol.sameValue(ctx, item.value, expected));

    const instances = try protocol.createSequenceOfPlatformObjects(here, &.{instance});
    defer instances.release();
    const first = try protocol.getProperty(here, instances.value, "0");
    defer first.release();
    try std.testing.expect(protocol.sameValue(ctx, first.value, expected));

    const frozen = try protocol.createFrozenArray(here, &.{platform_object});
    defer frozen.release();
    const frozen_first = try protocol.getProperty(here, frozen.value, "0");
    defer frozen_first.release();
    try std.testing.expect(protocol.sameValue(ctx, frozen_first.value, expected));

    const dictionary = try protocol.createDictionaryObject(here, &.{.{ .name = "member", .value = platform_object }});
    defer dictionary.release();
    const member = try protocol.getProperty(here, dictionary.value, "member");
    defer member.release();
    try std.testing.expect(protocol.sameValue(ctx, member.value, expected));

    const target = try Made.of("({})");
    defer target.deinit();
    try protocol.setProperty(here, target.value(), "set", platform_object);
    const set = try protocol.getProperty(here, target.value(), "set");
    defer set.release();
    try std.testing.expect(protocol.sameValue(ctx, set.value, expected));

    // An argument, and the callback this value.
    const identity = try identityFunction();
    defer identity.deinit();
    const returned = (try protocol.invokeCallbackFunction(here, &callbackFunction(identity.value(), null), .undefined, &.{platform_object}, .rethrow)).normal;
    defer returned.release();
    try std.testing.expect(protocol.sameValue(ctx, returned.value, expected));
    const self_function = try Made.of("(function () { 'use strict'; return this; })");
    defer self_function.deinit();
    const this_value = (try protocol.invokeCallbackFunction(here, &callbackFunction(self_function.value(), null), .{ .value = platform_object }, &.{}, .rethrow)).normal;
    defer this_value.release();
    try std.testing.expect(protocol.sameValue(ctx, this_value.value, expected));

    // A promise resolved with it.
    var capability = try protocol.createPromise(here);
    defer protocol.releasePromiseCapability(&capability);
    try protocol.resolvePromise(&capability, platform_object);
    ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate_once.?);
    const promise: *ffi.Promise = @ptrCast(@alignCast(capability.promise.handle.ptr));
    try std.testing.expectEqual(@as(c_int, 1), ffi.v8_Promise_State(promise));
    const result = ffi.v8_Promise_Result(promise) orelse return error.NoResult;
    defer ffi.v8_Value_Dispose(result);
    try std.testing.expect(protocol.sameValue(ctx, asValue(result), expected));
}
