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
