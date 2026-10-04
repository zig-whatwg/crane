//! HTML 2.7.1 serializable objects through V8's structured serialization
//! (src/runtime/engines/v8/serializable_objects.zig): a platform object
//! whose primary interface is [Serializable] runs its interface's
//! serialization steps into V8's stream and its deserialization steps out of
//! it, in a realm made as a page's is; any other platform object throws a
//! "DataCloneError" DOMException.
//!
//! Before: the serializer delegate's WriteHostObject threw DataCloneError for
//! every host object, so structuredClone(blob), postMessage(new DOMPoint())
//! and IndexedDB's put of a File all failed.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");
const webidl = @import("webidl");

/// One isolate and one bootstrap context for the whole file; V8 is never torn
/// down here (see engine_realm_operations_test.zig).
var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;
var pools_ready = false;
var window_once: ?runtime.Context = null;

fn agent() !*ffi.Isolate {
    if (isolate_once) |i| return i;
    interfaces.process_hooks.startHooksForTest();
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    v8.context_manager.init(std.heap.page_allocator) catch {};
    _ = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
    if (!pools_ready) {
        runtime.SlabAllocator.init(std.heap.page_allocator);
        runtime.ArenaAllocator.init(std.heap.page_allocator);
        pools_ready = true;
    }
    isolate_once = i;
    context_once = context;
    return i;
}

/// The test's host for a Window realm: it makes the realm's Window.
const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

/// A Window realm, made as a navigation makes one; one for the file.
fn window() !runtime.Context {
    if (window_once) |w| return w;
    const isolate = try agent();
    const w = try protocol.createWindowRealm(&.{
        .agent = @ptrCast(isolate),
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .global_this = .new_window_proxy,
        .parent = null,
        .create_global_object = WindowHost.createGlobalObject,
        .host = null,
    });
    window_once = w;
    return w;
}

const Ignored = struct {
    fn report(_: ?*anyopaque, _: *const protocol.ErrorInfo) void {}
    const reporter: protocol.Reporter = .{ .report = report, .host = null };
};

fn expectEval(r: runtime.Context, source: []const u8, expected: []const u8) !void {
    const got = try protocol.evaluateClassicScriptToString(r, .{ .utf8 = source }, "", null, std.testing.allocator, Ignored.reporter);
    defer std.testing.allocator.free(got);
    try std.testing.expectEqualStrings(expected, got);
}

test "the [Serializable] interfaces with steps are exactly this batch's" {
    const expected = [_][]const u8{
        "Blob",               "CryptoKey",       "DOMException",     "DOMMatrix",
        "DOMMatrixReadOnly",  "DOMPoint",        "DOMPointReadOnly", "DOMQuad",
        "DOMRect",            "DOMRectReadOnly", "File",             "ImageData",
        "QuotaExceededError",
    };
    const names = v8.serializable_objects.serializableInterfaces();
    try std.testing.expectEqual(expected.len, names.len);
    for (expected) |name| {
        try std.testing.expect(v8.serializable_objects.stepsFor(name) != null);
    }
    // Not [Serializable], or no steps: not in the table.
    try std.testing.expect(v8.serializable_objects.stepsFor("Response") == null);
    try std.testing.expect(v8.serializable_objects.stepsFor("MessagePort") == null);
    try std.testing.expect(v8.serializable_objects.stepsFor("FileList") == null);
}

test "structuredClone keeps a point, a rectangle and a matrix" {
    const w = try window();
    try expectEval(w,
        \\(() => {
        \\  const p = structuredClone(new DOMPoint(1, -2, 3.5, -0));
        \\  const q = structuredClone(new DOMPointReadOnly(NaN));
        \\  return [Object.getPrototypeOf(p) === DOMPoint.prototype, p.x, p.y, p.z, Object.is(p.w, -0),
        \\          Object.getPrototypeOf(q) === DOMPointReadOnly.prototype, q.x, q.w].join();
        \\})()
    , "true,1,-2,3.5,true,true,NaN,1");
    try expectEval(w,
        \\(() => {
        \\  const r = structuredClone(new DOMRect(1, 2, -3, 4));
        \\  const ro = structuredClone(new DOMRectReadOnly(0, 0, 5, 6));
        \\  return [r instanceof DOMRect, r.x, r.width, r.left, r.right, ro.height, ro.bottom].join();
        \\})()
    , "true,1,-3,-2,1,6,6");
    try expectEval(w,
        \\(() => {
        \\  const m = structuredClone(new DOMMatrix([1, 2, 3, 4, 5, 6]));
        \\  const values = Array.from({ length: 16 }, (_, i) => i + 1);
        \\  const m3 = structuredClone(new DOMMatrixReadOnly(values));
        \\  return [m instanceof DOMMatrix, m.is2D, m.a, m.f, m.m33,
        \\          Object.getPrototypeOf(m3) === DOMMatrixReadOnly.prototype, m3.is2D, m3.m12, m3.m44].join();
        \\})()
    , "true,true,1,6,1,true,false,2,16");
}

test "structuredClone keeps a quad's points, as new DOMPoints" {
    const w = try window();
    try expectEval(w,
        \\(() => {
        \\  const quad = new DOMQuad({ x: 1, y: 2 }, { x: 3, z: 4 }, { w: 5 }, { x: NaN });
        \\  const copy = structuredClone(quad);
        \\  return [copy instanceof DOMQuad, copy.p1 !== quad.p1, copy.p1 instanceof DOMPoint,
        \\          copy.p1.y, copy.p2.z, copy.p3.w, copy.p4.x].join();
        \\})()
    , "true,true,true,2,4,5,NaN");
}

test "structuredClone keeps a DOMException and a QuotaExceededError" {
    const w = try window();
    try expectEval(w,
        \\(() => {
        \\  const e = structuredClone(new DOMException("the message", "NotFoundError"));
        \\  const q = structuredClone(new QuotaExceededError("full", { quota: 1, requested: 2 }));
        \\  return [Object.getPrototypeOf(e) === DOMException.prototype, e.name, e.message, e.code,
        \\          Object.getPrototypeOf(q) === QuotaExceededError.prototype, q.name, q.message, q.quota, q.requested].join();
        \\})()
    , "true,NotFoundError,the message,8,true,QuotaExceededError,full,1,2");
}

test "structuredClone keeps a Blob's type and size, and a File's name and lastModified" {
    const w = try window();
    try expectEval(w,
        \\(() => {
        \\  const b = structuredClone(new Blob(["abc", new Uint8Array([0])], { type: "Text/Plain" }));
        \\  const f = structuredClone(new File(["xy"], "n.txt", { lastModified: 42 }));
        \\  class Sub extends File {}
        \\  const s = structuredClone(new Sub([], "s"));
        \\  return [Object.getPrototypeOf(b) === Blob.prototype, b.size, b.type,
        \\          Object.getPrototypeOf(f) === File.prototype, f.name, f.lastModified, f.size,
        \\          Object.getPrototypeOf(s) === File.prototype].join();
        \\})()
    , "true,4,text/plain,true,n.txt,42,2,true");
}

test "an ImageData's data is sub-serialized with the rest of the graph" {
    const w = try window();
    try expectEval(w,
        \\(() => {
        \\  const image = new ImageData(2, 1);
        \\  image.data.set([1, 2, 3, 4, 5, 6, 7, 8]);
        \\  const [copy, data] = structuredClone([image, image.data]);
        \\  return [copy instanceof ImageData, copy.width, copy.height, copy.colorSpace,
        \\          copy.data === data, copy.data !== image.data, Array.from(copy.data).join(" ")].join();
        \\})()
    , "true,2,1,srgb,true,true,1 2 3 4 5 6 7 8");
}

test "a platform object that is not [Serializable] throws DataCloneError, naming its interface" {
    const w = try window();
    try expectEval(w,
        \\(() => {
        \\  try { structuredClone({ inner: new AbortController() }); return "no throw"; }
        \\  catch (e) { return [e instanceof DOMException, e.name, e.message].join(); }
        \\})()
    , "true,DataCloneError,AbortController object could not be cloned.");
}

test "StructuredSerializeForStorage takes a bare platform object and StructuredDeserialize makes it anew" {
    const w = try window();
    // A DOMPoint as the binding hands one over: its Instance, unwrapped.
    const point = try interfaces.DOMPoint.call_constructor(w, webidl.Opt(f64).passed(7), webidl.Opt(f64).passed(8), webidl.Opt(f64).passed(9), webidl.Opt(f64).passed(10));
    const bytes = try protocol.structuredSerializeForStorage(w, .{ .instance = point }, std.testing.allocator);
    defer std.testing.allocator.free(bytes);
    const copy = try protocol.structuredDeserialize(w, bytes);
    defer copy.release();
    const instance = protocol.convertToPlatformObject(w, copy.borrow()) orelse return error.NotAPlatformObject;
    try std.testing.expect(instance != point);
    try std.testing.expectEqualStrings("DOMPoint", instance.vtable.name);
    try std.testing.expectEqual(@as(f64, 7), try interfaces.DOMPointReadOnly.get_x(instance));
    try std.testing.expectEqual(@as(f64, 10), try interfaces.DOMPointReadOnly.get_w(instance));
}

test "a record that names an interface this build does not deserialize is a DataCloneError" {
    const w = try window();
    // A serialized DOMPoint whose [[Type]] is renamed in place: same length,
    // an identifier no table entry has.
    const bytes = try protocol.structuredSerializeForStorage(w, .{ .instance = try interfaces.DOMPoint.call_constructor(w, webidl.Opt(f64).notPassed(), webidl.Opt(f64).notPassed(), webidl.Opt(f64).notPassed(), webidl.Opt(f64).notPassed()) }, std.testing.allocator);
    defer std.testing.allocator.free(bytes);
    const at = std.mem.indexOf(u8, bytes, "DOMPoint") orelse return error.NoTypeInRecord;
    @memcpy(bytes[at..][0..8], "XOMPoint");
    try std.testing.expectError(error.DataCloneError, protocol.structuredDeserialize(w, bytes));
}
