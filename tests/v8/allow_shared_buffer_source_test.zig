//! Converting to AllowSharedBufferSource - (ArrayBuffer or SharedArrayBuffer or
//! [AllowShared] ArrayBufferView), TextDecoder.decode's input among others -
//! through the V8 adapter's conversion.
//!
//! WebIDL 3.2.25: an ArrayBuffer (step 6) and a SharedArrayBuffer (step 7) are
//! members of the union as much as a typed array or a DataView (steps 8-9).
//! 3.2.26: the IDL value is a REFERENCE to the same object - the conversion
//! keeps the handle it was given and no bytes. The operation reads the bytes
//! at its own step ("get a copy of the bytes held by the buffer source",
//! `engine.getCopyOfAllowSharedBufferSourceBytes`): a view's own window of
//! its buffer, [[ByteOffset]] for [[ByteLength]]; none when the buffer is
//! detached - including when it was detached AFTER the conversion, which the
//! slice this conversion used to make read as the freed backing store.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const engine = @import("engine");
const ffi = v8.ffi;
const conv = v8.conversions;
const iface = v8.interface_mod;
const AllowSharedBufferSource = conv.generated_typedefs.AllowSharedBufferSource;
const testing_allocator = std.testing.allocator;

var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;
var realm_once: ?runtime.Context = null;

/// One isolate and realm for the file, registered with the context manager
/// so that the engine's operations can enter it; V8 is never torn down here.
fn setUp() !void {
    if (context_once != null) return;
    try engine.initializeEngine(.{});
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    v8.context_manager.init(std.heap.page_allocator) catch {};
    realm_once = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
    isolate_once = i;
    context_once = context;
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

/// `handle` converted, as the binding converts an argument: the value takes
/// the argument's handle, and freeing the value releases it.
fn convert(handle: *ffi.Value) !AllowSharedBufferSource {
    return conv.fromV8Value(AllowSharedBufferSource, testing_allocator, isolate_once.?, context_once.?, handle);
}

/// What the operation reads at its own step: a copy of the bytes the value's
/// object holds now. OWNED by the testing allocator.
fn bytesAtTheStep(source: AllowSharedBufferSource) ![]u8 {
    const value = source.jsValue(runtime.JSValue) orelse return error.NoReference;
    return (try engine.getCopyOfAllowSharedBufferSourceBytes(realm_once.?, value, testing_allocator)) orelse error.NotABufferSource;
}

/// `code`'s value converts to a reference whose bytes are `expected`.
fn expectBytes(code: []const u8, expected: []const u8) !void {
    try setUp();
    const handle = try eval(code);
    const source = convert(handle) catch |err| {
        ffi.v8_Value_Dispose(handle);
        std.debug.print("{s} did not convert: {s}\n", .{ code, @errorName(err) });
        return err;
    };
    // Releases `handle`, and an ArrayBuffer's or SharedArrayBuffer's struct.
    defer iface.freeConvertedArg(AllowSharedBufferSource, testing_allocator, source);
    // A reference to the object itself, holding no bytes.
    try std.testing.expectEqual(@as(?*anyopaque, @ptrCast(handle)), source.jsHandle());
    try std.testing.expectError(error.BytesHeldByEngine, source.asBytes());
    const bytes = try bytesAtTheStep(source);
    defer testing_allocator.free(bytes);
    std.testing.expectEqualSlices(u8, expected, bytes) catch |err| {
        std.debug.print("{s} read the wrong bytes\n", .{code});
        return err;
    };
}

test "an ArrayBuffer is a reference to it, and its bytes are its own" {
    try expectBytes("new Uint8Array([104, 105]).buffer", "hi");
}

test "a SharedArrayBuffer is a reference to it, and its bytes are its own" {
    try expectBytes("(() => { const s = new SharedArrayBuffer(3); new Uint8Array(s).set([1, 2, 3]); return s; })()", &.{ 1, 2, 3 });
}

test "a typed array's bytes are its own window of its buffer" {
    try expectBytes("new Uint8Array([1, 2, 3, 4, 5]).subarray(1, 4)", &.{ 2, 3, 4 });
    try expectBytes("new Uint16Array([0x0201, 0x0403, 0x0605]).subarray(1)", &.{ 3, 4, 5, 6 });
}

test "a DataView's bytes are its own window of its buffer, not its whole buffer" {
    try expectBytes("new DataView(new Uint8Array([1, 2, 3, 4, 5]).buffer, 1, 3)", &.{ 2, 3, 4 });
    try expectBytes("new DataView(new Uint8Array([7, 8]).buffer)", &.{ 7, 8 });
}

test "a view over a SharedArrayBuffer is allowed ([AllowShared])" {
    try expectBytes("(() => { const s = new SharedArrayBuffer(4); new Uint8Array(s).set([9, 8, 7, 6]); return new Uint8Array(s, 1, 2); })()", &.{ 8, 7 });
    try expectBytes("(() => { const s = new SharedArrayBuffer(4); new Uint8Array(s).set([9, 8, 7, 6]); return new DataView(s, 2); })()", &.{ 7, 6 });
}

test "a detached ArrayBuffer, and a view over one, hold no bytes" {
    try expectBytes("(() => { const b = new Uint8Array([1, 2]).buffer; b.transfer(); return b; })()", &.{});
    try expectBytes("(() => { const v = new Uint8Array([1, 2]); v.buffer.transfer(); return v; })()", &.{});
    try expectBytes("(() => { const v = new DataView(new Uint8Array([1, 2]).buffer); v.buffer.transfer(); return v; })()", &.{});
}

// The defect: a buffer converted, THEN detached by script that runs before the
// operation reads it - as a later argument's getter does
// (TextDecoder.decode(input, { get stream() { input.buffer.transfer(0) } })).
// The conversion used to keep the address and length of the backing store;
// the transfer frees that store, so what the conversion kept is recorded here
// before and after: the address it would have kept, and the object's own
// answer once detached. The reference reads what the object holds now.
test "a buffer detached after its conversion reads as empty, not as its freed store" {
    try setUp();
    const kinds = [_][]const u8{
        "globalThis.input = new Uint8Array(10000).fill(42)",
        "globalThis.input = new Uint8Array(10000).fill(42).buffer",
        "globalThis.input = new DataView(new Uint8Array(10000).fill(42).buffer, 1, 9998)",
    };
    for (kinds) |code| {
        const handle = try eval(code);
        const source = try convert(handle);
        defer iface.freeConvertedArg(AllowSharedBufferSource, testing_allocator, source);

        // What a slice taken at conversion would have held.
        var stale_data: ?*anyopaque = null;
        var stale_length: usize = 0;
        try std.testing.expect(ffi.v8_AllowSharedBufferSource_Bytes(handle, &stale_data, &stale_length));
        try std.testing.expect(stale_data != null);
        try std.testing.expect(stale_length >= 9998);

        // Script runs between the conversion and the operation's step.
        const detach = try eval("(ArrayBuffer.prototype.isPrototypeOf(input) ? input : input.buffer).transfer(0), 0");
        ffi.v8_Value_Dispose(detach);

        // The object now holds nothing: the address above is freed.
        var data: ?*anyopaque = null;
        var length: usize = 0;
        try std.testing.expect(ffi.v8_AllowSharedBufferSource_Bytes(handle, &data, &length));
        try std.testing.expectEqual(@as(usize, 0), length);

        // The reference still refers to the object, and reads it as it is.
        try std.testing.expectEqual(@as(?*anyopaque, @ptrCast(handle)), source.jsHandle());
        const bytes = try bytesAtTheStep(source);
        defer testing_allocator.free(bytes);
        if (bytes.len != 0) {
            std.debug.print("{s}: {d} bytes read after the transfer freed the store at {*} ({d} bytes)\n", .{ code, bytes.len, stale_data, stale_length });
            return error.ReadFreedStore;
        }
    }
}

/// A dictionary with an AllowSharedBufferSource member and one converted
/// after it, shaped as codegen emits EncodedVideoChunkInit's `data` and
/// `timestamp` (members convert in lexicographic order: data, then
/// timestamp).
const InitWithData = struct {
    data: AllowSharedBufferSource,
    timestamp: i64,
};

// The same through a dictionary: the member converts to a reference to its
// object (the handle Get made for it, kept in the value and released with the
// dictionary), and the later member's getter detaches the buffer before the
// operation's step reads it.
test "a dictionary member a later member's getter detaches reads as empty" {
    try setUp();
    const init = try eval(
        \\(() => {
        \\  const data = new Uint8Array(10000).fill(42);
        \\  return { data, get timestamp() { data.buffer.transfer(0); return 1; } };
        \\})()
    );
    defer ffi.v8_Value_Dispose(init);
    const dict = try conv.fromV8Value(InitWithData, testing_allocator, isolate_once.?, context_once.?, init);
    // Releases the member's handle; the testing allocator fails on a leak of
    // anything the conversion allocated.
    defer iface.freeConvertedArg(InitWithData, testing_allocator, dict);
    try std.testing.expectEqual(@as(i64, 1), dict.timestamp);
    try std.testing.expect(dict.data.jsHandle() != null);
    const bytes = try bytesAtTheStep(dict.data);
    defer testing_allocator.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), bytes.len);
}

test "null and undefined hold no bytes and no reference" {
    try setUp();
    for ([_][]const u8{ "null", "undefined" }) |code| {
        const handle = try eval(code);
        const source = try convert(handle);
        // No reference kept: the binding releases the argument's handle at
        // once (keptArgumentHandle is null), as this does.
        ffi.v8_Value_Dispose(handle);
        defer iface.freeConvertedArg(AllowSharedBufferSource, testing_allocator, source);
        try std.testing.expectEqual(@as(?*anyopaque, null), source.jsHandle());
        try std.testing.expectEqual(@as(usize, 0), (try source.asBytes()).len);
    }
}

// ---------------------------------------------------------------------------
// engine.borrowBufferSourceBytes: the same bytes read in place, for a
// non-shared buffer only
// ---------------------------------------------------------------------------

/// `code`'s value converted as the binding converts an argument; `check`
/// runs on it, and the value is freed after.
fn withConverted(code: []const u8, check: *const fn (AllowSharedBufferSource, *ffi.Value) anyerror!void) !void {
    try setUp();
    const handle = try eval(code);
    const source = try convert(handle);
    defer iface.freeConvertedArg(AllowSharedBufferSource, testing_allocator, source);
    try check(source, handle);
}

/// Borrowed bytes equal to `expected`, at the address the object's own
/// bytes are at: read in place, not copied.
fn expectBorrowed(code: []const u8, comptime expected: []const u8) !void {
    try withConverted(code, struct {
        fn check(source: AllowSharedBufferSource, handle: *ffi.Value) !void {
            const bytes = engine.borrowBufferSourceBytes(realm_once.?, source.jsValue(runtime.JSValue).?) orelse return error.NotBorrowed;
            try std.testing.expectEqualSlices(u8, expected, bytes);
            if (expected.len == 0) return;
            var data: ?*anyopaque = null;
            var length: usize = 0;
            try std.testing.expect(ffi.v8_AllowSharedBufferSource_Bytes(handle, &data, &length));
            try std.testing.expectEqual(@as([*]const u8, @ptrCast(data.?)), bytes.ptr);
        }
    }.check);
}

test "borrowBufferSourceBytes reads an ArrayBuffer and a view's window in place" {
    try expectBorrowed("new Uint8Array([104, 105]).buffer", "hi");
    try expectBorrowed("new Uint8Array([1, 2, 3, 4, 5]).subarray(1, 4)", &.{ 2, 3, 4 });
    try expectBorrowed("new Uint16Array([0x0201, 0x0403, 0x0605]).subarray(1)", &.{ 3, 4, 5, 6 });
    try expectBorrowed("new DataView(new Uint8Array([1, 2, 3, 4, 5]).buffer, 1, 3)", &.{ 2, 3, 4 });
    // A small typed array V8 keeps on its own heap: Buffer() moves it off
    // first, so the address the borrow gives is the one the object keeps.
    try expectBorrowed("new Uint8Array([7])", &.{7});
}

test "borrowBufferSourceBytes reads a detached buffer as empty" {
    try expectBorrowed("(() => { const b = new Uint8Array([1, 2]).buffer; b.transfer(); return b; })()", &.{});
    try expectBorrowed("(() => { const v = new Uint8Array([1, 2]); v.buffer.transfer(); return v; })()", &.{});
    try expectBorrowed("(() => { const v = new DataView(new Uint8Array([1, 2]).buffer); v.buffer.transfer(); return v; })()", &.{});
}

// Shared memory is never borrowed: another agent can write it while it is
// read. The copy still reads it.
test "borrowBufferSourceBytes refuses a SharedArrayBuffer and a view over one; the copy takes them" {
    const shared = [_][]const u8{
        "(() => { const s = new SharedArrayBuffer(2); new Uint8Array(s).set([1, 2]); return s; })()",
        "(() => { const s = new SharedArrayBuffer(2); new Uint8Array(s).set([1, 2]); return new Uint8Array(s); })()",
        "(() => { const s = new SharedArrayBuffer(2); new Uint8Array(s).set([1, 2]); return new DataView(s); })()",
    };
    for (shared) |code| {
        try withConverted(code, struct {
            fn check(source: AllowSharedBufferSource, _: *ffi.Value) !void {
                try std.testing.expectEqual(@as(?[]const u8, null), engine.borrowBufferSourceBytes(realm_once.?, source.jsValue(runtime.JSValue).?));
                const bytes = try bytesAtTheStep(source);
                defer testing_allocator.free(bytes);
                try std.testing.expectEqualSlices(u8, &.{ 1, 2 }, bytes);
            }
        }.check);
    }
}

test "borrowBufferSourceBytes answers null for anything that is not a buffer source" {
    try setUp();
    try std.testing.expectEqual(@as(?[]const u8, null), engine.borrowBufferSourceBytes(realm_once.?, .{ .number = 1 }));
    try std.testing.expectEqual(@as(?[]const u8, null), engine.borrowBufferSourceBytes(realm_once.?, runtime.JSValue.jsNull));
    const object = try eval("({ byteLength: 2 })");
    defer ffi.v8_Value_Dispose(object);
    try std.testing.expectEqual(@as(?[]const u8, null), engine.borrowBufferSourceBytes(realm_once.?, runtime.JSValue.fromHandle(object)));
}

// What decode() relies on: borrowed at its step, after a getter detached the
// buffer, the bytes are none - never the freed store.
test "a buffer detached after its conversion borrows as empty" {
    try withConverted("globalThis.input = new Uint8Array(10000).fill(42)", struct {
        fn check(source: AllowSharedBufferSource, _: *ffi.Value) !void {
            const detach = try eval("input.buffer.transfer(0), 0");
            ffi.v8_Value_Dispose(detach);
            const bytes = engine.borrowBufferSourceBytes(realm_once.?, source.jsValue(runtime.JSValue).?) orelse return error.NotBorrowed;
            try std.testing.expectEqual(@as(usize, 0), bytes.len);
        }
    }.check);
}

test "anything else is a TypeError" {
    try setUp();
    const cases = [_][]const u8{ "({ byteLength: 2 })", "'hi'", "4", "[1, 2]", "Symbol()" };
    for (cases) |code| {
        const handle = try eval(code);
        defer ffi.v8_Value_Dispose(handle);
        if (convert(handle)) |source| {
            iface.freeConvertedArg(AllowSharedBufferSource, testing_allocator, source);
            std.debug.print("{s} converted to an AllowSharedBufferSource\n", .{code});
            return error.TestUnexpectedResult;
        } else |err| try std.testing.expectEqual(error.TypeError, err);
    }
}
