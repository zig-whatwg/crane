//! A platform object an operation returns is wrapped in its relevant realm -
//! the realm it was created in (`instance.ctx`) - whichever realm the
//! operation's function belongs to (engine rule 4; WebIDL 3.2.24 "the
//! result of converting a platform object is the reference to it", and a
//! platform object has one wrapper per realm it is in: its own).
//!
//! The binding's operation result path wrapped an Instance in the CALLING
//! function's context: a method borrowed from a frame returned the page's
//! objects as the frame's - a second wrapper, with the frame's prototype -
//! so `frame.Blob.prototype.slice.call(pageBlob)` was no page Blob, and
//! `frame.ReadableStream.prototype.pipeThrough.call(rs, ts)` was not
//! `ts.readable` (codex-indexeddb Q43: IDBFactory.open borrowed from another
//! realm returned a request that was not the event's target).
//!
//! The realms are made as a page's and its frame's are (createWindowRealm
//! with the frame's parent), so the frame shares the page's access.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

var isolate_once: ?*ffi.Isolate = null;
var pools_ready = false;

fn agent() !*ffi.Isolate {
    if (isolate_once) |i| return i;
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    // Already initialized is fine: the manager is per thread, not per test.
    v8.context_manager.init(std.heap.page_allocator) catch {};
    _ = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
    if (!pools_ready) {
        runtime.SlabAllocator.init(std.heap.page_allocator);
        runtime.ArenaAllocator.init(std.heap.page_allocator);
        pools_ready = true;
    }
    isolate_once = i;
    return i;
}

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

fn windowRealmIn(parent: ?runtime.Context) !runtime.Context {
    const isolate = try agent();
    return protocol.createWindowRealm(&.{
        .agent = @ptrCast(isolate),
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .global_this = .new_window_proxy,
        .parent = parent,
        .create_global_object = WindowHost.createGlobalObject,
        .host = null,
    });
}

const Ignored = struct {
    fn report(_: ?*anyopaque, _: *const protocol.ErrorInfo) void {}
    const reporter: protocol.Reporter = .{ .report = report, .host = null };
};

fn evalOwned(r: runtime.Context, source: []const u8) !protocol.Owned {
    return protocol.evaluateClassicScript(r, .{ .utf8 = source }, "", null, Ignored.reporter);
}

fn expectEval(r: runtime.Context, source: []const u8, expected: []const u8) !void {
    const got = try protocol.evaluateClassicScriptToString(r, .{ .utf8 = source }, "", null, std.testing.allocator, Ignored.reporter);
    defer std.testing.allocator.free(got);
    try std.testing.expectEqualStrings(expected, got);
}

/// Give `to`'s global a property `name` whose value is `source` evaluated in
/// `from`.
fn share(from: runtime.Context, source: []const u8, to: runtime.Context, name: []const u8) !void {
    const value = try evalOwned(from, source);
    defer value.release();
    const global = try evalOwned(to, "globalThis");
    defer global.release();
    try protocol.defineOwnProperty(to, global.value, name, value.value, .{ .writable = true, .enumerable = false, .configurable = true });
}

test "an object a method borrowed from another realm returns is wrapped in its own realm" {
    const page = try windowRealmIn(null);
    defer protocol.destroyWindowRealm(page, .global_detached);
    const frame = try windowRealmIn(page);
    defer protocol.destroyWindowRealm(frame, .global_detached);

    // Blob.slice makes its result in this's realm: the page's.
    try share(frame, "Blob.prototype.slice", page, "frameSlice");
    try expectEval(page, "const pageBlob = new Blob(['abc']); const sliced = frameSlice.call(pageBlob, 1); String(Object.getPrototypeOf(sliced) === Blob.prototype)", "true");
    try expectEval(page, "String(sliced instanceof Blob)", "true");
}

test "an object of another realm returned by this realm's method keeps its own realm's wrapper" {
    const page = try windowRealmIn(null);
    defer protocol.destroyWindowRealm(page, .global_detached);
    const frame = try windowRealmIn(page);
    defer protocol.destroyWindowRealm(frame, .global_detached);

    try share(frame, "new Blob(['xyz'])", page, "frameBlob");
    try share(frame, "Blob.prototype", page, "frameBlobPrototype");
    try expectEval(page, "String(Object.getPrototypeOf(Blob.prototype.slice.call(frameBlob, 1)) === frameBlobPrototype)", "true");
}

test "an existing object a borrowed method returns is the one wrapper its realm has" {
    const page = try windowRealmIn(null);
    defer protocol.destroyWindowRealm(page, .global_detached);
    const frame = try windowRealmIn(page);
    defer protocol.destroyWindowRealm(frame, .global_detached);

    // pipeThrough returns the pair's readable: an object the page already
    // has a wrapper for.
    try share(frame, "ReadableStream.prototype.pipeThrough", page, "framePipeThrough");
    try expectEval(page, "const ts = new TransformStream(); const piped = framePipeThrough.call(new ReadableStream(), ts); String(piped === ts.readable)", "true");
}
