//! Buffer source and `object` arguments through the real binding: what a
//! conversion makes of them, and that no handle outlives the call.
//!
//! WebIDL 3.2.26: a BufferSource or ArrayBufferView IDL value "is a reference
//! to the same object" as the JavaScript value - not a copy of its bytes, and
//! never a slice into its backing store (a getter a later step runs can
//! transfer the buffer). The binding hands the impl that reference, BORROWED
//! for the call, and releases it once the call returns; a spec copies the
//! bytes at its own step (engine.getCopyOfBufferSourceBytes). An `object`
//! union arm (AlgorithmIdentifier = (object or DOMString)) is the same: the
//! argument's own handle, borrowed, released after the call.
//!
//! The handle tests read V8's own live count (`v8_Isolate_GetGlobalHandleBytes`,
//! docs/lessons/testing-a-handle-leak-test-needs-v8-s-live-count.md) against a
//! control call run the same way (docs/lessons/testing-a-counter-that-drifts-
//! per-call-hides-a-leak-per-call.md): the control takes the same binding path
//! with arguments whose handles are copied out.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const engine = @import("engine");
const interfaces = @import("interfaces");
const ffi = v8.ffi;

var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;
var realm_once: ?runtime.Context = null;

/// One isolate and realm for the file, registered with the context manager
/// as a page's is, every interface installed; V8 is never torn down here.
fn realm() !runtime.Context {
    if (realm_once) |r| return r;
    try engine.initializeEngine(.{});
    interfaces.process_hooks.startHooksForTest();
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    v8.context_manager.init(std.heap.page_allocator) catch {};
    const r = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
    runtime.SlabAllocator.init(std.heap.page_allocator);
    runtime.ArenaAllocator.init(std.heap.page_allocator);
    v8.interface_bindings.registerAllInterfaces(i, context);
    isolate_once = i;
    context_once = context;
    realm_once = r;
    return r;
}

/// The value `code` evaluates to: a Global the caller disposes, made the way
/// the binding's `info.get(i)` makes an argument's.
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

fn setGlobal(name: []const u8, value: *ffi.Value) !void {
    const context = context_once.?;
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(isolate_once.?, name.ptr, @intCast(name.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    if (!ffi.v8_Object_Set(global, context, @ptrCast(key), value)) return error.SetFailed;
}

/// A platform object of `Interface`, made in the file's realm and reachable
/// from script as `globalThis[name]`. Its wrapper is the wrapper cache's.
fn exposeInstance(comptime Interface: type, name: []const u8) !void {
    const r = try realm();
    const instance = try Interface.init(std.heap.page_allocator, r);
    try setGlobal(name, v8.conversions.instanceToV8(isolate_once.?, instance));
}

var crypto_exposed = false;
var subtle_exposed = false;

fn cryptoObject() !void {
    _ = try realm();
    if (crypto_exposed) return;
    try exposeInstance(interfaces.Crypto, "testCrypto");
    crypto_exposed = true;
}

fn subtleObject() !void {
    _ = try realm();
    if (subtle_exposed) return;
    try exposeInstance(interfaces.SubtleCrypto, "testSubtle");
    subtle_exposed = true;
}

/// V8's global handle bytes left by 64 runs of `body`, after a collection.
/// Two runs first, so that what the first call makes and later ones reuse
/// is not counted.
fn handleBytesLeftBy(comptime body: []const u8) !i64 {
    const isolate = isolate_once.?;
    const loop = "(() => { for (let i = 0; i < {N}; i++) { " ++ body ++ " } return 0 })()";
    _ = try evalInt(comptime replaceN(loop, "2"));
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    const before: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(isolate));
    _ = try evalInt(comptime replaceN(loop, "64"));
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    return @as(i64, @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(isolate))) - before;
}

fn replaceN(comptime loop: []const u8, comptime n: []const u8) []const u8 {
    const at = std.mem.indexOf(u8, loop, "{N}").?;
    return loop[0..at] ++ n ++ loop[at + 3 ..];
}

/// What one Global costs in V8's count.
fn oneHandleBytes() i64 {
    const isolate = isolate_once.?;
    const start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    const one = ffi.v8_Number_New(isolate, 1);
    const with_one = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    ffi.v8_Value_Dispose(@ptrCast(one));
    return @intCast(with_one - start);
}

/// `body` leaves no more global handles than `control`: under one handle per
/// eight runs, so a handle left per call (64 of them) cannot hide.
fn expectNoMoreThanControl(comptime what: []const u8, comptime body: []const u8, comptime control: []const u8) !void {
    const control_left = try handleBytesLeftBy(control);
    const left = try handleBytesLeftBy(body);
    const one = oneHandleBytes();
    if (left - control_left >= one * 8) {
        std.debug.print("64 runs of {s} left {d} bytes of global handles; the control left {d} ({d} bytes a handle)\n", .{ what, left, control_left, one });
        return error.HandlesLeaked;
    }
}

// ---------------------------------------------------------------------------
// Through the binding: no argument handle outlives the call
// ---------------------------------------------------------------------------

test "an ArrayBufferView argument leaves no handle once the call returns" {
    try cryptoObject();
    // Crypto.getRandomValues(ArrayBufferView): converted, the call made (the
    // impl's answer does not matter here), the argument released. The
    // control is the same object's zero-argument operation.
    try expectNoMoreThanControl(
        "testCrypto.getRandomValues(new Uint8Array(4))",
        "try { testCrypto.getRandomValues(new Uint8Array(4)) } catch (e) {}",
        "try { testCrypto.randomUUID() } catch (e) {}",
    );
}

test "a BufferSource argument leaves no handle once the call returns" {
    try subtleObject();
    // SubtleCrypto.digest(AlgorithmIdentifier, BufferSource), a typed array
    // and an ArrayBuffer. The control rejects the same way, on arguments
    // whose handles are copied out (an enum, and a number for the key).
    try expectNoMoreThanControl(
        "testSubtle.digest('SHA-256', new Uint8Array(4))",
        "testSubtle.digest('SHA-256', new Uint8Array(4)).catch(() => {});",
        "testSubtle.exportKey('raw', 5).catch(() => {});",
    );
    try expectNoMoreThanControl(
        "testSubtle.digest('SHA-256', new ArrayBuffer(4))",
        "testSubtle.digest('SHA-256', new ArrayBuffer(4)).catch(() => {});",
        "testSubtle.exportKey('raw', 5).catch(() => {});",
    );
}

test "an argument that is not a BufferSource leaves no handle either" {
    try subtleObject();
    // A failed conversion made nothing that refers to the argument.
    try expectNoMoreThanControl(
        "testSubtle.digest('SHA-256', {})",
        "testSubtle.digest('SHA-256', {}).catch(() => {});",
        "testSubtle.exportKey('raw', 5).catch(() => {});",
    );
}

test "an object argument for (object or DOMString) leaves no handle once the call returns" {
    try subtleObject();
    try expectNoMoreThanControl(
        "testSubtle.digest({ name: 'SHA-256' }, new Uint8Array(4))",
        "testSubtle.digest({ name: 'SHA-256' }, new Uint8Array(4)).catch(() => {});",
        "testSubtle.exportKey('raw', 5).catch(() => {});",
    );
}

// ---------------------------------------------------------------------------
// What the conversion makes: a reference to the object, not its bytes
// ---------------------------------------------------------------------------

const conv = v8.conversions;
const iface = v8.interface_mod;
const typedefs = conv.generated_typedefs;
const BufferSource = iface.non_owning_arg_types.BufferSource;
const ArrayBufferView = iface.non_owning_arg_types.ArrayBufferView;
const testing_allocator = std.testing.allocator;

fn toBufferSource(handle: *ffi.Value) !BufferSource {
    return conv.fromV8Value(BufferSource, testing_allocator, isolate_once.?, context_once.?, handle);
}

/// The bytes a spec copies at its own step, through the reference.
fn copyOf(source: BufferSource) ![]u8 {
    const r = try realm();
    return (try v8.webidl_conversions.getCopyOfBufferSourceBytes(r, source.jsValue(runtime.JSValue).?, testing_allocator)).?;
}

test "a typed array converts to a reference to itself, and a copy taken later sees later bytes" {
    _ = try realm();
    const handle = try eval("globalThis.u8 = new Uint8Array([1, 2, 3, 4]); u8");
    defer ffi.v8_Value_Dispose(handle);
    const source = try toBufferSource(handle);
    // No clone: the IDL value refers to the very handle converted from.
    try std.testing.expect(source == .array_buffer_view);
    try std.testing.expectEqual(@as(?*anyopaque, @ptrCast(handle)), source.jsHandle());
    // A getter run between conversion and the spec's copy (WebCrypto's
    // normalize-an-algorithm) changes what the copy reads.
    _ = try evalInt("u8[0] = 9; 0");
    const bytes = try copyOf(source);
    defer testing_allocator.free(bytes);
    try std.testing.expectEqualSlices(u8, &.{ 9, 2, 3, 4 }, bytes);
    // The bytes are the engine's: no slice into the backing store.
    try std.testing.expectError(error.BytesHeldByEngine, source.asBytes());
}

test "an ArrayBuffer converts to a reference, and one transferred before the copy reads as empty" {
    _ = try realm();
    const handle = try eval("globalThis.ab = new Uint8Array([5, 6]).buffer; ab");
    defer ffi.v8_Value_Dispose(handle);
    const source = try toBufferSource(handle);
    defer testing_allocator.destroy(source.array_buffer);
    try std.testing.expect(source == .array_buffer);
    try std.testing.expectEqual(@as(?*anyopaque, @ptrCast(handle)), source.jsHandle());
    try std.testing.expectEqual(@as(usize, 0), source.array_buffer.data.len);
    try std.testing.expectError(error.BytesHeldByEngine, source.asBytes());
    const before = try copyOf(source);
    defer testing_allocator.free(before);
    try std.testing.expectEqualSlices(u8, &.{ 5, 6 }, before);
    // "with transferred plaintext during call": the buffer is detached.
    _ = try evalInt("globalThis.moved = ab.transfer(); 0");
    const after = try copyOf(source);
    defer testing_allocator.free(after);
    try std.testing.expectEqual(@as(usize, 0), after.len);
}

test "a DataView converts to a view of its own window" {
    _ = try realm();
    const handle = try eval("new DataView(new Uint8Array([1, 2, 3, 4]).buffer, 1, 2)");
    defer ffi.v8_Value_Dispose(handle);
    const source = try toBufferSource(handle);
    try std.testing.expect(source.array_buffer_view == .data_view);
    try std.testing.expectEqual(@as(usize, 1), source.array_buffer_view.getByteOffset());
    const bytes = try copyOf(source);
    defer testing_allocator.free(bytes);
    try std.testing.expectEqualSlices(u8, &.{ 2, 3 }, bytes);
}

test "a SharedArrayBuffer, a view over one, and anything not a buffer are TypeErrors" {
    _ = try realm();
    const cases = [_][]const u8{
        "new SharedArrayBuffer(4)",
        "new Uint8Array(new SharedArrayBuffer(4))",
        "new DataView(new SharedArrayBuffer(4))",
        "({ byteLength: 4 })",
        "'bytes'",
        "4",
        "null",
        "undefined",
        "[1, 2]",
    };
    for (cases) |code| {
        const handle = try eval(code);
        defer ffi.v8_Value_Dispose(handle);
        if (toBufferSource(handle)) |_| {
            std.debug.print("{s} converted to a BufferSource\n", .{code});
            return error.TestUnexpectedResult;
        } else |err| try std.testing.expectEqual(error.TypeError, err);
    }
}

test "an ArrayBufferView converts to a reference to itself, and an ArrayBuffer is no view" {
    _ = try realm();
    const handle = try eval("new Int16Array([1, 2, 3])");
    defer ffi.v8_Value_Dispose(handle);
    const view = try conv.fromV8Value(ArrayBufferView, testing_allocator, isolate_once.?, context_once.?, handle);
    try std.testing.expect(view == .int16_array);
    try std.testing.expectEqual(@as(?*anyopaque, @ptrCast(handle)), view.jsHandle());
    try std.testing.expectEqual(@as(?usize, 3), view.getArrayLength());

    const buffer = try eval("new ArrayBuffer(4)");
    defer ffi.v8_Value_Dispose(buffer);
    try std.testing.expectError(error.TypeError, conv.fromV8Value(ArrayBufferView, testing_allocator, isolate_once.?, context_once.?, buffer));
}

test "a view result can be pointed at a hold of its own" {
    var buffer = ArrayBufferViewBuffer{};
    const view = ArrayBufferView.fromEngine(1, 0, 4, @ptrCast(&buffer.a)).?;
    const moved = view.withJsHandle(@ptrCast(&buffer.b));
    try std.testing.expectEqual(@as(?*anyopaque, @ptrCast(&buffer.b)), moved.jsHandle());
    try std.testing.expectEqual(view.getByteLength(), moved.getByteLength());
    try std.testing.expect(moved == .uint8_array);
}

const ArrayBufferViewBuffer = struct { a: u64 = 0, b: u64 = 0 };

test "an (object or DOMString) union takes any Object as a reference, and everything else as a string" {
    _ = try realm();
    const AlgorithmIdentifier = typedefs.AlgorithmIdentifier;
    const objects = [_][]const u8{ "({ name: 'SHA-256' })", "[1]", "(function () {})", "new Uint8Array(1)", "new String('s')" };
    for (objects) |code| {
        const handle = try eval(code);
        defer ffi.v8_Value_Dispose(handle);
        const value = try conv.fromV8Value(AlgorithmIdentifier, testing_allocator, isolate_once.?, context_once.?, handle);
        try std.testing.expect(value == .object);
        try std.testing.expectEqual(@as(*anyopaque, @ptrCast(handle)), value.object.handle.ptr);
    }
    const strings = [_]struct { code: []const u8, text: []const u8 }{
        .{ .code = "'SHA-256'", .text = "SHA-256" },
        .{ .code = "5", .text = "5" },
        .{ .code = "null", .text = "null" },
    };
    for (strings) |case| {
        const handle = try eval(case.code);
        defer ffi.v8_Value_Dispose(handle);
        var value = try conv.fromV8Value(AlgorithmIdentifier, testing_allocator, isolate_once.?, context_once.?, handle);
        try std.testing.expect(value == .domstring);
        defer value.domstring.deinit(testing_allocator);
        try std.testing.expectEqualStrings(case.text, value.domstring.asSlice());
    }
    // A Symbol is no Object, and ToString throws for it.
    const symbol = try eval("Symbol('s')");
    defer ffi.v8_Value_Dispose(symbol);
    try std.testing.expectError(error.TypeError, conv.fromV8Value(AlgorithmIdentifier, testing_allocator, isolate_once.?, context_once.?, symbol));
}

// ---------------------------------------------------------------------------
// The ownership predicates: which values keep their argument's handle
// ---------------------------------------------------------------------------

test "argumentHandleIsKeptInValue - buffer sources and object arms are decided by their value" {
    const webidl = @import("webidl");
    const kept = iface.argumentHandleIsKeptInValue;
    try std.testing.expect(kept(BufferSource));
    try std.testing.expect(kept(ArrayBufferView));
    try std.testing.expect(kept(?BufferSource));
    try std.testing.expect(kept(webidl.Opt(BufferSource)));
    try std.testing.expect(kept(webidl.Opt(?ArrayBufferView)));
    try std.testing.expect(kept(typedefs.AlgorithmIdentifier));
    try std.testing.expect(kept(webidl.Opt(typedefs.AlgorithmIdentifier)));
    try std.testing.expect(kept(runtime.JSValue));
    // A union whose only non-copying arms are buffer sources.
    const BufferOrText = union(enum) { buffer_source: BufferSource, usvstring: []const u8 };
    try std.testing.expect(kept(BufferOrText));
}

test "argumentHandleIsKeptInValue - an unknown type, or a JSValue arm not named object, defaults to NO" {
    const kept = iface.argumentHandleIsKeptInValue;
    try std.testing.expect(!kept(runtime.DOMString));
    try std.testing.expect(!kept([]const BufferSource));
    // CryptoKeyID's JSValue arm is `bigint`, not `object`.
    try std.testing.expect(!kept(typedefs.CryptoKeyID));
    const Shape = union(enum) { value: runtime.JSValue, text: runtime.DOMString };
    try std.testing.expect(!kept(Shape));
    const SomethingNew = struct { a: u32, b: *anyopaque };
    try std.testing.expect(!kept(SomethingNew));
    const BufferOrCallback = union(enum) { buffer_source: BufferSource, callback: *anyopaque };
    try std.testing.expect(!kept(BufferOrCallback));
}

test "argHandleIsCopied - a buffer source is a reference, never copied" {
    // Copied would release the argument's handle at conversion, under the
    // reference the impl is about to read.
    try std.testing.expect(!iface.argHandleIsCopied(BufferSource));
    try std.testing.expect(!iface.argHandleIsCopied(ArrayBufferView));
    try std.testing.expect(!iface.argHandleIsCopied(typedefs.AlgorithmIdentifier));
}

test "keptArgumentHandle - the handle a value still refers to, or null" {
    const webidl = @import("webidl");
    var slot: u64 = 0;
    const handle: *anyopaque = @ptrCast(&slot);
    const view = ArrayBufferView.fromEngine(1, 0, 1, handle).?;
    try std.testing.expectEqual(@as(?*anyopaque, handle), iface.keptArgumentHandle(BufferSource, .{ .array_buffer_view = view }));
    try std.testing.expectEqual(@as(?*anyopaque, null), iface.keptArgumentHandle(?BufferSource, null));
    try std.testing.expectEqual(@as(?*anyopaque, null), iface.keptArgumentHandle(webidl.Opt(BufferSource), webidl.Opt(BufferSource).notPassed()));
    const object: typedefs.AlgorithmIdentifier = .{ .object = .{ .handle = .{ .ptr = handle } } };
    try std.testing.expectEqual(@as(?*anyopaque, handle), iface.keptArgumentHandle(typedefs.AlgorithmIdentifier, object));
    const text: typedefs.AlgorithmIdentifier = .{ .domstring = runtime.DOMString.initEmpty() };
    try std.testing.expectEqual(@as(?*anyopaque, null), iface.keptArgumentHandle(typedefs.AlgorithmIdentifier, text));
}

test "freeing a converted buffer source releases its reference and its struct" {
    _ = try realm();
    const isolate = isolate_once.?;
    // V8's live count, before and after 32 conversions freed the binding's
    // way; std.testing.allocator fails the test on an ArrayBuffer struct left.
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    for (0..32) |_| {
        const buffer = try eval("new ArrayBuffer(8)");
        const source = try toBufferSource(buffer);
        iface.freeBufferSourceArg(BufferSource, testing_allocator, source);
        const view = try eval("new Float64Array(2)");
        const as_view = try toBufferSource(view);
        iface.freeBufferSourceArg(BufferSource, testing_allocator, as_view);
    }
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    try std.testing.expect(ffi.v8_Isolate_GetGlobalHandleBytes(isolate) <= before);
}

// ---------------------------------------------------------------------------
// A view result is the binding's, as a JSValue result is
// ---------------------------------------------------------------------------

test "a view a getter returns is released once it is the result, and stays the request's" {
    _ = try realm();
    // ReadableStreamBYOBRequest.view returns the request's [[view]]: over a
    // hold of the binding's own (the binding releases every view result), so
    // neither a read's handle is left behind nor the request's freed.
    try std.testing.expectEqual(@as(i32, 8), try evalInt(
        \\globalThis.byobController = null;
        \\globalThis.byobReader = new ReadableStream({ type: 'bytes', start(c) { byobController = c; } }).getReader({ mode: 'byob' });
        \\byobReader.read(new Uint8Array(8));
        \\globalThis.byobRequestObject = byobController.byobRequest;
        \\byobRequestObject.view.byteLength
    ));
    try expectNoMoreThanControl(
        "byobRequest.view",
        "void byobRequestObject.view.byteLength;",
        "void byobController.desiredSize;",
    );
    ffi.v8_Isolate_RequestGarbageCollection(isolate_once.?);
    try std.testing.expectEqual(@as(i32, 1), try evalInt("byobRequestObject.view === byobRequestObject.view && byobRequestObject.view.byteLength === 8 ? 1 : 0"));
}

// ---------------------------------------------------------------------------
// A copied type is never also "kept in value": one release, not two
// ---------------------------------------------------------------------------

test "argumentHandleIsKeptInValue is false for every type argHandleIsCopied accepts, BodyInit among them" {
    const BodyInit = iface.copied_arg_types.BodyInit;
    // BodyInit's XMLHttpRequestBodyInit arm holds a BufferSource, but
    // convertBodyInit copies the bytes: the type is copied, and must not also
    // be kept, or the dictionary member loop releases a RequestInit's body
    // member's handle twice.
    try std.testing.expect(iface.argHandleIsCopied(BodyInit));
    try std.testing.expect(!iface.argumentHandleIsKeptInValue(BodyInit));
    try std.testing.expect(!iface.argumentHandleIsKeptInValue(?BodyInit));
    try std.testing.expect(!iface.bufferHandleIsKeptInValue(BodyInit));
    const copied_types = .{ runtime.DOMString, ?runtime.DOMString, u32, bool, *runtime.Instance, []const runtime.DOMString, BodyInit, ?BodyInit };
    inline for (copied_types) |T| {
        try std.testing.expect(iface.argHandleIsCopied(T));
        try std.testing.expect(!iface.argumentHandleIsKeptInValue(T));
    }
}

test "a dictionary with a copied BodyInit member releases its handle once" {
    _ = try realm();
    // RequestInit's `body` (BodyInit, copied) and `signal` (an interface,
    // copied): each member's Get handle is released exactly once. Twice was a
    // crash in every fetch(url, init).
    try expectNoMoreThanControl(
        "new Request(url, { method: 'POST', body: 'x' })",
        "try { new Request('https://example.test/', { method: 'POST', body: 'x' }) } catch (e) {}",
        "try { new Request('https://example.test/') } catch (e) {}",
    );
    try expectNoMoreThanControl(
        "new Request(url, { method: 'POST', body: new Uint8Array(2) })",
        "try { new Request('https://example.test/', { method: 'POST', body: new Uint8Array(2) }) } catch (e) {}",
        "try { new Request('https://example.test/') } catch (e) {}",
    );
}
