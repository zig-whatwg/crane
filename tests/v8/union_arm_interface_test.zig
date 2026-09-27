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
        .engine = &v8.engine.v8_engine_interface,
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
