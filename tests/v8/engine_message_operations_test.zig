//! The Engine table's message operations, as V8 implements them:
//! structuredSerializeWithTransfer, structuredDeserializeWithTransfer,
//! convertToSequenceOfObjects and createFrozenArrayOfPlatformObjects.
//!
//! What MessagePort, Worker and a worker's global scope post goes through
//! these (AGENTS.md, "The engine boundary"): HTML 2.7.5 and 2.7.7 at the seam,
//! with the transferred ArrayBuffers' contents and the transferred platform
//! objects handed across as engine-neutral data.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;

const engine = &v8.engine.v8_engine_interface;
const allocator = std.testing.allocator;

/// Two realms in one isolate - sender and receiver - for the whole file.
var isolate_once: ?*ffi.Isolate = null;
var contexts: [2]*ffi.Context = undefined;
var realms: [2]*runtime.ContextData = undefined;
var ready = false;

fn setup() !void {
    if (ready) return;
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    ffi.v8_Isolate_SetMicrotasksPolicy(i, @intFromEnum(ffi.MicrotasksPolicy.Explicit));
    _ = ffi.v8_HandleScope_New(i);
    for (&contexts, &realms) |*context, *data| {
        context.* = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
        const r = try runtime.Realm.init(std.heap.page_allocator, .{ .v8_context = context.*, .isolate = i });
        const d = try std.heap.page_allocator.create(runtime.ContextData);
        d.* = try runtime.ContextData.init(std.heap.page_allocator, .{ .engine = engine, .engine_ctx = context.*, .realm = r });
        data.* = d;
    }
    ffi.v8_Context_Enter(contexts[0]);
    isolate_once = i;
    ready = true;
}

/// `code`'s completion value in realm `which`: an owned Global.
fn eval(which: usize, code: []const u8) !*ffi.Value {
    const context = contexts[which];
    const text = ffi.v8_String_NewFromUtf8(isolate_once.?, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse error.RunFailed;
}

fn evalInt(which: usize, code: []const u8) !i32 {
    const value = try eval(which, code);
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, contexts[which]);
}

fn setGlobal(which: usize, name: []const u8, handle: *anyopaque) !void {
    const context = contexts[which];
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(isolate_once.?, name.ptr, @intCast(name.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    _ = ffi.v8_Object_Set(global, context, @ptrCast(key), @ptrCast(@alignCast(handle)));
}

fn asValue(handle: *ffi.Value) runtime.JSValue {
    return .{ .handle = .{ .ptr = @ptrCast(handle), .needs_disposal = false, .handle_scope = .global } };
}

// Platform objects: objects with internal fields whose field 0 is a mock
// Instance, as the bindings wrap them.
const mock_methods: u8 = 0;
const mock_vtable = runtime.VTable{ .name = "MockPort", .deinit = null, .methods_ptr = &mock_methods };
var mock_ports: [2]runtime.Instance = undefined;

fn installPorts() !void {
    const context = contexts[0];
    const template = ffi.v8_ObjectTemplate_New(isolate_once.?);
    defer ffi.v8_ObjectTemplate_Dispose(template);
    ffi.v8_ObjectTemplate_SetInternalFieldCount(template, 2);
    for (&mock_ports, [_][]const u8{ "p", "q" }) |*instance, name| {
        instance.* = .{ .vtable = &mock_vtable, .state = undefined, .ctx = realms[0] };
        const object = ffi.v8_ObjectTemplate_NewInstance(template, context) orelse return error.InstanceFailed;
        defer ffi.v8_Object_Dispose(object);
        ffi.v8_Object_SetAlignedPointerInInternalField(object, 0, @ptrCast(instance));
        ffi.v8_Object_SetAlignedPointerInInternalField(object, 1, null);
        try setGlobal(0, name, @ptrCast(object));
    }
}

/// The caller's answer: `p` transferable, `q` detached, anything else not -
/// and the check data it was given, recorded.
var seen_check_data: ?*anyopaque = null;
fn checkPorts(data: ?*anyopaque, instance: *runtime.Instance) runtime.TransferableState {
    seen_check_data = data;
    if (instance == &mock_ports[0]) return .transferable;
    if (instance == &mock_ports[1]) return .detached;
    return .not_transferable;
}

/// A list of borrowed handles for the items of the array `code` makes.
const List = struct {
    array: *ffi.Value,
    items: []runtime.JSValue,

    fn of(code: []const u8) !List {
        const array = try eval(0, code);
        errdefer ffi.v8_Value_Dispose(array);
        const items = try engine.convertToSequenceOfObjects.?(realms[0], asValue(array), allocator);
        return .{ .array = array, .items = items };
    }

    fn deinit(self: List) void {
        for (self.items) |item| engine.releaseValue.?(item);
        allocator.free(self.items);
        ffi.v8_Value_Dispose(self.array);
    }
};

// ----------------------------------------------------------------------------
// convertToSequenceOfObjects
// ----------------------------------------------------------------------------

test "a sequence of objects is each item's own handle, in order" {
    try setup();
    const list = try List.of("globalThis.o1 = {}; globalThis.o2 = []; [o1, o2]");
    defer list.deinit();
    try std.testing.expectEqual(@as(usize, 2), list.items.len);
    try std.testing.expect(list.items[0].handle.needs_disposal);
    try setGlobal(0, "first", list.items[0].handle.ptr);
    try std.testing.expectEqual(@as(i32, 1), try evalInt(0, "first === o1 ? 1 : 0"));
}

test "a non-object item or a non-iterable is a TypeError" {
    try setup();
    const mixed = try eval(0, "[{}, 1]");
    defer ffi.v8_Value_Dispose(mixed);
    try std.testing.expectError(error.TypeError, engine.convertToSequenceOfObjects.?(realms[0], asValue(mixed), allocator));
    try std.testing.expectError(error.TypeError, engine.convertToSequenceOfObjects.?(realms[0], runtime.JSValue.jsUndefined, allocator));
}

// ----------------------------------------------------------------------------
// createFrozenArrayOfPlatformObjects
// ----------------------------------------------------------------------------

test "a frozen array holds each platform object's wrapper, and is frozen" {
    try setup();
    try installPorts();
    // The mock instances have no wrapper cache: the array made of none is
    // what is pinned here, and the empty list MessageEvent.ports uses most.
    const empty = try engine.createFrozenArrayOfPlatformObjects.?(realms[1], &.{});
    defer engine.releaseValue.?(empty);
    try std.testing.expect(empty.handle.needs_disposal);
    try setGlobal(1, "ports", empty.handle.ptr);
    try std.testing.expectEqual(@as(i32, 1), try evalInt(1, "Array.isArray(ports) && ports.length === 0 && Object.isFrozen(ports) ? 1 : 0"));
    // Made in the realm it was asked for.
    try std.testing.expectEqual(@as(i32, 1), try evalInt(1, "Object.getPrototypeOf(ports) === Array.prototype ? 1 : 0"));
}

// ----------------------------------------------------------------------------
// structuredSerializeWithTransfer / structuredDeserializeWithTransfer
// ----------------------------------------------------------------------------

test "a value round-trips into a second realm, and its transferred buffer moves" {
    try setup();
    const value = try eval(0, "globalThis.buf = new Uint8Array([1, 2, 3]).buffer; ({ a: 1, s: 'x', buf })");
    defer ffi.v8_Value_Dispose(value);
    const transfer = try List.of("[buf]");
    defer transfer.deinit();

    var result = try engine.structuredSerializeWithTransfer.?(realms[0], asValue(value), transfer.items, checkPorts, null, allocator);
    defer result.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 1), result.array_buffers.len);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, result.array_buffers[0]);
    try std.testing.expectEqual(@as(usize, 0), result.platform_objects.len);
    // The sender's buffer is detached.
    try std.testing.expectEqual(@as(i32, 0), try evalInt(0, "buf.byteLength"));

    const clone = try engine.structuredDeserializeWithTransfer.?(realms[1], result.serialized, result.array_buffers);
    defer engine.releaseValue.?(clone);
    try std.testing.expect(clone.handle.needs_disposal);
    try setGlobal(1, "v", clone.handle.ptr);
    try std.testing.expectEqual(@as(i32, 1), try evalInt(1,
        \\v.a === 1 && v.s === 'x' && v.buf.byteLength === 3 && new Uint8Array(v.buf)[2] === 3 &&
        \\Object.getPrototypeOf(v) === Object.prototype ? 1 : 0
    ));
}

test "primitives serialize too" {
    try setup();
    const empty: []const runtime.JSValue = &.{};
    var number = try engine.structuredSerializeWithTransfer.?(realms[0], .{ .number = 42 }, empty, checkPorts, null, allocator);
    defer number.deinit(allocator);
    const back = try engine.structuredDeserializeWithTransfer.?(realms[1], number.serialized, &.{});
    defer engine.releaseValue.?(back);
    try setGlobal(1, "n", back.handle.ptr);
    try std.testing.expectEqual(@as(i32, 42), try evalInt(1, "n"));
}

test "a duplicate or detached buffer, and a non-transferable entry, are DataCloneErrors" {
    try setup();
    try installPorts();
    const value = try eval(0, "globalThis.d = new ArrayBuffer(4); globalThis.gone = new ArrayBuffer(4); gone.transfer(); 1");
    defer ffi.v8_Value_Dispose(value);

    const twice = try List.of("[d, d]");
    defer twice.deinit();
    try std.testing.expectError(error.DataCloneError, engine.structuredSerializeWithTransfer.?(realms[0], asValue(value), twice.items, checkPorts, null, allocator));

    const detached = try List.of("[gone]");
    defer detached.deinit();
    try std.testing.expectError(error.DataCloneError, engine.structuredSerializeWithTransfer.?(realms[0], asValue(value), detached.items, checkPorts, null, allocator));

    const plain = try List.of("[{}]");
    defer plain.deinit();
    try std.testing.expectError(error.DataCloneError, engine.structuredSerializeWithTransfer.?(realms[0], asValue(value), plain.items, checkPorts, null, allocator));
    // Nothing was detached by the failures.
    try std.testing.expectEqual(@as(i32, 4), try evalInt(0, "d.byteLength"));
}

test "a transferable platform object is handed back, asked about with the caller's data" {
    try setup();
    try installPorts();
    var marker: u8 = 0;
    const transfer = try List.of("[p]");
    defer transfer.deinit();
    var result = try engine.structuredSerializeWithTransfer.?(realms[0], .{ .number = 1 }, transfer.items, checkPorts, &marker, allocator);
    defer result.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 1), result.platform_objects.len);
    try std.testing.expectEqual(&mock_ports[0], result.platform_objects[0]);
    try std.testing.expectEqual(@as(?*anyopaque, &marker), seen_check_data);

    // Detached (q), and the same object twice, are DataCloneErrors.
    const detached = try List.of("[q]");
    defer detached.deinit();
    try std.testing.expectError(error.DataCloneError, engine.structuredSerializeWithTransfer.?(realms[0], .{ .number = 1 }, detached.items, checkPorts, null, allocator));
    const twice = try List.of("[p, p]");
    defer twice.deinit();
    try std.testing.expectError(error.DataCloneError, engine.structuredSerializeWithTransfer.?(realms[0], .{ .number = 1 }, twice.items, checkPorts, null, allocator));
}

/// A native that serializes its argument as postMessage does, returning 1,
/// or -1 for a DataCloneError; an ExceptionPending returns nothing, so the
/// exception reaches the script.
fn serializeArgument(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const argument = info.get(0);
    defer ffi.v8_Global_Dispose(argument);
    const empty: []const runtime.JSValue = &.{};
    // As an impl gets it: the binding's form of the argument (an object is a
    // `.handle` tagged `.local` whose pointer is the argument's Global).
    var value = v8.conversions.fromV8Value(runtime.JSValue, allocator, isolate_once.?, contexts[0], argument) catch return;
    defer value.deinit(allocator);
    const result: f64 = if (engine.structuredSerializeWithTransfer.?(realms[0], value, empty, checkPorts, null, allocator)) |r| blk: {
        var owned = r;
        owned.deinit(allocator);
        break :blk 1;
    } else |err| switch (err) {
        error.ExceptionPending => return,
        else => -1,
    };
    const number = ffi.v8_Number_New(info.getIsolate(), result);
    defer ffi.v8_Value_Dispose(@ptrCast(number));
    info.setReturnValue(@ptrCast(number));
}

test "what serialization throws - a getter, a DataCloneError DOMException - is pending for the script" {
    try setup();
    const context = contexts[0];
    const template = ffi.v8_FunctionTemplate_New(isolate_once.?, serializeArgument, null) orelse return error.TemplateFailed;
    defer ffi.v8_FunctionTemplate_Dispose(template);
    const function = ffi.v8_FunctionTemplate_GetFunction(template, context) orelse return error.FunctionFailed;
    defer ffi.v8_Function_Dispose(function);
    try setGlobal(0, "serialize", @ptrCast(function));

    try std.testing.expectEqual(@as(i32, 1), try evalInt(0, "serialize({ a: [1, 2] })"));
    try std.testing.expectEqual(@as(i32, 1), try evalInt(0,
        \\(() => {
        \\  const boom = new Error("getter");
        \\  try { serialize({ get x() { throw boom; } }); } catch (e) { return e === boom ? 1 : 0; }
        \\  return -1;
        \\})()
    ));
    // A function cannot be serialized: V8 throws (no DOMException constructor
    // in this bare realm, so an Error saying why).
    try std.testing.expectEqual(@as(i32, 1), try evalInt(0,
        \\(() => { try { serialize(() => 1); } catch (e) { return e instanceof Error ? 1 : 0; } return -1; })()
    ));
}

test "bytes that do not deserialize are a DataCloneError" {
    try setup();
    try std.testing.expectError(error.DataCloneError, engine.structuredDeserializeWithTransfer.?(realms[1], "not serialized", &.{}));
}
