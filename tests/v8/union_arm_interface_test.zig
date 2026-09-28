//! WebIDL §3.2.24 step 4 - which member interface a platform object goes to
//! in a union with interface arms.
//!
//! A generated union arm of interface type is a bare `*runtime.Instance`: the
//! Zig type does not say WHICH interface. The conversion used to put any
//! wrapped object into the first such arm, so `fetch(new URL(...))` handed a
//! URL to the Request constructor as a Request, and `div.append(blob)` handed
//! a Blob to the DOM as a Node. The interface is recovered from the arm's
//! name, which codegen derives from the interface's (`sanitizeTypeName`), and
//! the object's state ancestry is asked whether it implements it.
//!
//! An arm whose name maps to no interface cannot be checked and accepts any
//! platform object - the old behaviour. That default is pinned below, and so
//! is the property that makes it rare: every interface arm of every
//! generated union typedef maps to an interface.

const std = @import("std");
const v8 = @import("v8");
const runtime = @import("runtime");

const conv = v8.conversions;

fn nameOf(comptime arm: []const u8) ?[]const u8 {
    return conv.unionArmInterfaceName(arm);
}

test "arm names map back to the interfaces codegen derived them from" {
    try std.testing.expectEqualStrings("Request", nameOf("request").?);
    try std.testing.expectEqualStrings("Node", nameOf("node").?);
    try std.testing.expectEqualStrings("ReadableStream", nameOf("readable_stream").?);
    // Runs of capitals: no underscore until a capital follows a lower-case
    // letter.
    try std.testing.expectEqualStrings("URLSearchParams", nameOf("urlsearch_params").?);
    try std.testing.expectEqualStrings("HTMLVideoElement", nameOf("htmlvideo_element").?);
    try std.testing.expectEqualStrings("ReadableStreamBYOBReader", nameOf("readable_stream_byobreader").?);
    // A digit neither starts nor ends a word.
    try std.testing.expectEqualStrings("WebGL2RenderingContext", nameOf("web_gl2rendering_context").?);
}

test "a typedef of an interface type maps to the interface" {
    // MessageEventSource's first arm is WindowProxy, a typedef for Window.
    try std.testing.expectEqualStrings("Window", nameOf("window_proxy").?);
}

test "an arm naming no interface maps to nothing, so it cannot be checked" {
    // The default: `implementsArm` accepts any platform object for such an
    // arm - what every arm did before the check existed. It must stay rare;
    // the next test is what keeps it so.
    try std.testing.expect(nameOf("no_such_interface") == null);
    try std.testing.expect(nameOf("usvstring") == null);
    try std.testing.expect(nameOf("") == null);
}

test "every interface arm of every generated union typedef maps to an interface" {
    @setEvalBranchQuota(10_000_000);
    const typedefs = conv.generated_typedefs;
    var checked: usize = 0;
    inline for (comptime std.meta.declarations(typedefs)) |decl| {
        const T = @field(typedefs, decl.name);
        if (@TypeOf(T) == type and @typeInfo(T) == .@"union") {
            inline for (@typeInfo(T).@"union".fields) |field| {
                if (field.type == *runtime.Instance) {
                    if (comptime nameOf(field.name) == null) {
                        std.debug.print("{s}.{s} names no interface\n", .{ decl.name, field.name });
                        return error.UnmappedUnionArm;
                    }
                    checked += 1;
                }
            }
        }
    }
    // BodyInit, RequestInfo, MessageEventSource, BlobPart and the rest.
    try std.testing.expect(checked > 40);
}

// =============================================================================
// A callable, with and without a callback function arm (§3.2.24 step 11)
// =============================================================================
//
// A function is an object. It goes to a callback function arm when the union
// has one; otherwise it continues through the object steps and, failing
// those, to the string step. The conversion used to stop at "is a function"
// and answer TypeError, so `new Request(URL)` - the URL constructor as the
// input - threw instead of fetching the string it stringifies to.

const ffi = v8.ffi;

/// A live isolate with an entered context, one for the whole file, as in
/// platform_task_pump_test.zig - V8 is never torn down here.
var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;

fn isolate() !*ffi.Isolate {
    if (isolate_once) |i| return i;
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    isolate_once = i;
    context_once = context;
    return i;
}

fn run(i: *ffi.Isolate, source: []const u8) !*ffi.Value {
    const context = context_once.?;
    const code = ffi.v8_String_NewFromUtf8(i, source.ptr, @intCast(source.len)) orelse return error.StringFailed;
    const script = ffi.v8_Script_Compile(context, code) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse return error.RunFailed;
}

test "a function given to a union with no callback arm is the string it stringifies to" {
    const i = try isolate();
    const value = try run(i, "(function input() {})");
    defer ffi.v8_Value_Dispose(value);
    const RequestInfo = conv.generated_typedefs.RequestInfo;
    const result = try conv.fromV8Value(RequestInfo, std.testing.allocator, i, context_once.?, value);
    try std.testing.expect(result == .usvstring);
    defer if (result.usvstring.len > 0) std.testing.allocator.free(result.usvstring);
    try std.testing.expectEqualStrings("function input() {}", result.usvstring);
}

test "a function given to a union with a callback arm is the callback" {
    const i = try isolate();
    const value = try run(i, "(function handler() {})");
    defer ffi.v8_Value_Dispose(value);
    const TimerHandler = conv.generated_typedefs.TimerHandler;
    const result = try conv.fromV8Value(TimerHandler, std.testing.allocator, i, context_once.?, value);
    try std.testing.expect(result == .function);
}

// =============================================================================
// streams_js.Deferred: the settled cell lives from init to deinit
// =============================================================================
//
// [[PromiseState]] has no engine operation, so a Deferred records its own
// settling in a cell it allocates with its realm's allocator. That realm's
// allocator is injected here as std.testing.allocator: a cell deinit forgets,
// or frees twice, fails the test.

const js = @import("impls").Response.streams_js;

/// Make `data` a realm over this file's isolate and context whose allocator
/// is std.testing.allocator. The caller deinits it.
fn initTestingRealm(data: *runtime.ContextData) !void {
    const i = try isolate();
    data.* = try runtime.ContextData.init(std.testing.allocator, .{
        .engine_ctx = context_once.?,
    });
    data.agent = @ptrCast(i);
}

test "a Deferred's settled cell is allocated, settled and freed with the Deferred" {
    var data: runtime.ContextData = undefined;
    try initTestingRealm(&data);
    defer data.deinit();
    const realm = try js.Realm.ofContext(&data);

    const deferred = try js.Deferred.init(realm);
    try std.testing.expect(deferred.isPending());
    deferred.resolve(realm, try realm.undefinedValue());
    try std.testing.expect(!deferred.isPending());
    // Settling a settled promise is a no-op, as in the spec.
    const reason = try realm.typeError("late");
    defer js.dispose(reason);
    deferred.reject(realm, reason);
    try std.testing.expect(!deferred.isPending());
    deferred.deinit();
}

test "copies of a Deferred share its cell, and deinitResolverOnly frees it too" {
    var data: runtime.ContextData = undefined;
    try initTestingRealm(&data);
    defer data.deinit();
    const realm = try js.Realm.ofContext(&data);

    const deferred = try js.Deferred.init(realm);
    const copy = deferred;
    copy.reject(realm, try realm.undefinedValue());
    try std.testing.expect(!deferred.isPending());
    // The promise stays the caller's after deinitResolverOnly.
    const promise = deferred.promise;
    deferred.deinitResolverOnly();
    js.dispose(promise);
}

// =============================================================================
// Blob: sequence<BlobPart>, and the promises the read methods return
// =============================================================================
//
// BlobPart is (Blob or BufferSource or USVString): a platform object that is
// no Blob, and anything else that is no buffer source, is the string it
// converts to (WebIDL 3.2.24 step 12). The sequence is any iterable. The
// read methods' promises are settled with the whole blob, and each call
// leaves no engine handle behind.

const Blob = @import("impls").Blob;
const protocol = @import("engine");

/// The process-wide pools a platform object's Instance comes from, made
/// once for the file and, like V8 here, never torn down.
fn ensurePools() void {
    if (runtime.SlabAllocator.tryGet()) |_| {} else |_| runtime.SlabAllocator.init(std.heap.page_allocator);
    if (runtime.ArenaAllocator.tryGet()) |_| {} else |_| runtime.ArenaAllocator.init(std.heap.page_allocator);
}

/// The value `source` evaluates to in this file's context. OWNED.
fn evalValue(source: []const u8) !protocol.Owned {
    return .{ .value = runtime.JSValue.fromHandle(@ptrCast(try run(try isolate(), source))) };
}

fn blobPartsOf(realm: runtime.Context, source: []const u8, endings: Blob.Endings) ![]const u8 {
    const parts = try evalValue(source);
    defer parts.release();
    return Blob.processBlobParts(realm, parts.value, endings);
}

test "a BlobPart is a buffer source's bytes, or else the USVString it converts to" {
    var data: runtime.ContextData = undefined;
    try initTestingRealm(&data);
    defer data.deinit();
    const bytes = try blobPartsOf(&data,
        \\[ 'aé', new Uint8Array([98, 99]).subarray(1), new ArrayBuffer(1),
        \\  new DataView(new Uint8Array([100, 101, 102]).buffer, 1, 1), 7, {}, null, '\ud800' ]
    , .transparent);
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualStrings("a\xc3\xa9c\x00e7[object Object]null\xef\xbf\xbd", bytes);
}

test "a sequence<BlobPart> is any iterable, and a value with no @@iterator is a TypeError" {
    var data: runtime.ContextData = undefined;
    try initTestingRealm(&data);
    defer data.deinit();
    const from_set = try blobPartsOf(&data, "new Set(['x', 'y'])", .transparent);
    defer std.testing.allocator.free(from_set);
    try std.testing.expectEqualStrings("xy", from_set);
    const from_generator = try blobPartsOf(&data, "(function* () { yield 'g'; yield new Uint8Array([104]); })()", .transparent);
    defer std.testing.allocator.free(from_generator);
    try std.testing.expectEqualStrings("gh", from_generator);
    // 3.2.21 step 1: not an Object; step 3: no @@iterator.
    try std.testing.expectError(error.TypeError, blobPartsOf(&data, "'abc'", .transparent));
    try std.testing.expectError(error.TypeError, blobPartsOf(&data, "null", .transparent));
    try std.testing.expectError(error.TypeError, blobPartsOf(&data, "({ length: 1, 0: 'a' })", .transparent));
}

test "endings: native converts a string part's line endings, and never a buffer's" {
    var data: runtime.ContextData = undefined;
    try initTestingRealm(&data);
    defer data.deinit();
    const bytes = try blobPartsOf(&data, "['a\\r\\nb\\rc\\n', new Uint8Array([13, 10])]", .native);
    defer std.testing.allocator.free(bytes);
    const nl = @import("builtin").os.tag != .windows;
    try std.testing.expectEqualStrings(if (nl) "a\nb\nc\n\r\n" else "a\r\nb\r\nc\r\n\r\n", bytes);
}

/// The value `promise` (OWNED, released here) is fulfilled with. OWNED.
fn fulfillmentOf(promise: runtime.JSValue) !*ffi.Value {
    defer protocol.releaseValue(.{ .value = promise });
    const p: *ffi.Promise = @ptrCast(@alignCast(promise.handle.ptr));
    try std.testing.expectEqual(@as(c_int, 1), ffi.v8_Promise_State(p)); // fulfilled
    return ffi.v8_Promise_Result(p) orelse error.NoResult;
}

test "Blob.text() is the UTF-8 decode of its bytes: the BOM stripped, an invalid byte U+FFFD" {
    var data: runtime.ContextData = undefined;
    try initTestingRealm(&data);
    defer data.deinit();
    ensurePools();
    const blob = try Blob.createFromBytes(std.testing.allocator, &data, "\xef\xbb\xbfa\xffb", "");
    defer Blob.deinit(blob);
    const text = try fulfillmentOf(try Blob.call_text(blob));
    defer ffi.v8_Value_Dispose(text);
    const decoded = try protocol.convertToDOMString(&data, runtime.JSValue.fromHandleNonOwning(@ptrCast(text)), std.testing.allocator);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualStrings("a\xef\xbf\xbdb", decoded);
}

test "Blob.arrayBuffer() and bytes() are fulfilled with a copy of every byte" {
    var data: runtime.ContextData = undefined;
    try initTestingRealm(&data);
    defer data.deinit();
    ensurePools();
    const blob = try Blob.createFromBytes(std.testing.allocator, &data, "\x00\x01\xff", "");
    defer Blob.deinit(blob);

    const buffer = try fulfillmentOf(try Blob.call_arrayBuffer(blob));
    defer ffi.v8_Value_Dispose(buffer);
    const buffer_value = runtime.JSValue.fromHandleNonOwning(@ptrCast(buffer));
    try std.testing.expectEqualSlices(u8, "\x00\x01\xff", protocol.borrowArrayBufferBytes(&data, buffer_value) orelse return error.NotABuffer);

    const view = try fulfillmentOf(try Blob.call_bytes(blob));
    defer ffi.v8_Value_Dispose(view);
    const view_value = runtime.JSValue.fromHandleNonOwning(@ptrCast(view));
    const description = protocol.describeArrayBufferView(&data, view_value) orelse return error.NotAView;
    try std.testing.expectEqual(protocol.ViewType.uint8_array, description.view_type);
    try std.testing.expectEqual(@as(usize, 3), description.byte_length);
    const viewed = try protocol.getViewedArrayBuffer(&data, view_value);
    defer viewed.release();
    try std.testing.expectEqualSlices(u8, "\x00\x01\xff", protocol.borrowArrayBufferBytes(&data, viewed.value) orelse return error.NotABuffer);
}

/// Run `method` on a Blob 33 times, each promise released, and expect no
/// more engine handles alive after the last 32 than after the first.
fn expectNoHandleLeft(comptime method: fn (*runtime.Instance) anyerror!runtime.JSValue) !void {
    var data: runtime.ContextData = undefined;
    try initTestingRealm(&data);
    defer data.deinit();
    ensurePools();
    const blob = try Blob.createFromBytes(std.testing.allocator, &data, "abc", "");
    defer Blob.deinit(blob);
    protocol.releaseValue(.{ .value = try method(blob) });
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate_once.?);
    for (0..32) |_| protocol.releaseValue(.{ .value = try method(blob) });
    try std.testing.expect(ffi.v8_Isolate_GetGlobalHandleBytes(isolate_once.?) <= before);
}

test "Blob.text() leaves no engine handle behind" {
    try expectNoHandleLeft(Blob.call_text);
}

test "Blob.arrayBuffer() leaves no engine handle behind" {
    try expectNoHandleLeft(Blob.call_arrayBuffer);
}

test "Blob.bytes() leaves no engine handle behind" {
    try expectNoHandleLeft(Blob.call_bytes);
}

// =============================================================================
// Response: the body methods' values are released once they settle
// =============================================================================
//
// Each method's value - an ArrayBuffer, a Uint8Array, a string - is made,
// the promise is settled with it, and it is let go: the promise holds it
// from there. A null body reads as no bytes, so the steps run inside the
// method call.

const Response = @import("impls").Response;

test "Response.arrayBuffer(), bytes() and text() leave no engine handle behind" {
    var data: runtime.ContextData = undefined;
    try initTestingRealm(&data);
    defer data.deinit();
    const params = @typeInfo(@TypeOf(Response.call_constructor)).@"fn".params;
    ensurePools();
    const response = try Response.call_constructor(&data, params[1].type.?.notPassed(), params[2].type.?.notPassed());
    defer Response.deinit(response);
    const round = struct {
        fn run(r: *runtime.Instance) !void {
            protocol.releaseValue(.{ .value = try Response.call_arrayBuffer(r) });
            protocol.releaseValue(.{ .value = try Response.call_bytes(r) });
            protocol.releaseValue(.{ .value = try Response.call_text(r) });
        }
    }.run;
    try round(response);
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate_once.?);
    for (0..32) |_| try round(response);
    try std.testing.expect(ffi.v8_Isolate_GetGlobalHandleBytes(isolate_once.?) <= before);
}

test "Response.arrayBuffer() of a null body is fulfilled with an empty ArrayBuffer" {
    var data: runtime.ContextData = undefined;
    try initTestingRealm(&data);
    defer data.deinit();
    const params = @typeInfo(@TypeOf(Response.call_constructor)).@"fn".params;
    ensurePools();
    const response = try Response.call_constructor(&data, params[1].type.?.notPassed(), params[2].type.?.notPassed());
    defer Response.deinit(response);
    const buffer = try fulfillmentOf(try Response.call_arrayBuffer(response));
    defer ffi.v8_Value_Dispose(buffer);
    try std.testing.expect(ffi.v8_Value_IsArrayBuffer(buffer));
}
