//! A realm whose settings object is not a secure context exposes no
//! [SecureContext] interface object or member (WebIDL 3.3.13 and "exposed").
//!
//! Nothing read [SecureContext]: every realm exposed navigator.locks,
//! LockManager, SubtleCrypto... and window.isSecureContext was true on http
//! (web-locks/non-secure-context.any.js). The host now passes HTML 8.1.3.5's
//! answer in WindowRealmOptions.secure_context; the realm records it
//! (ContextData.secure_context) and hides the constructs as its interface
//! objects are made. A secure realm - the default - is the control.

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
    v8.context_manager.init(std.heap.page_allocator) catch {};
    _ = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
    if (!pools_ready) {
        runtime.initializeRuntime(std.heap.page_allocator);
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

fn windowRealm(secure_context: bool, parent: ?runtime.Context) !runtime.Context {
    const isolate = try agent();
    return protocol.createWindowRealm(&.{
        .agent = @ptrCast(isolate),
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "http://example.test",
        .global_this = .new_window_proxy,
        .parent = parent,
        .create_global_object = WindowHost.createGlobalObject,
        .host = null,
        .secure_context = secure_context,
    });
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

/// What the realm exposes, as one string: a [SecureContext] interface
/// (LockManager), one exposed only to secure contexts through a partial
/// (Navigator's `locks`, from the [SecureContext] NavigatorLocks mixin), a
/// [SecureContext] member of a non-[SecureContext] interface (Crypto's
/// `subtle`), and an interface that is always exposed (Navigator).
const probe =
    \\[typeof LockManager, typeof SubtleCrypto, 'locks' in Navigator.prototype,
    \\ 'subtle' in Crypto.prototype, typeof Navigator, typeof Crypto].join()
;

test "a realm that is not a secure context exposes no [SecureContext] interface or member" {
    const page = try windowRealm(false, null);
    defer protocol.destroyWindowRealm(page, .global_detached);
    try std.testing.expect(!page.secure_context);
    try expectEval(page, probe, "undefined,undefined,false,false,function,function");
}

test "a secure realm exposes them - the default" {
    const page = try windowRealm(true, null);
    defer protocol.destroyWindowRealm(page, .global_detached);
    try std.testing.expect(page.secure_context);
    try expectEval(page, probe, "function,function,true,true,function,function");
}

test "Window's own [SecureContext] members are not on a non-secure window" {
    const insecure = try windowRealm(false, null);
    defer protocol.destroyWindowRealm(insecure, .global_detached);
    const secure = try windowRealm(true, null);
    defer protocol.destroyWindowRealm(secure, .global_detached);
    // `caches` is [SecureContext] in a partial WindowOrWorkerGlobalScope
    // (service-workers); `fetch` is not.
    try expectEval(insecure, "['caches' in self, typeof Object.getOwnPropertyDescriptor(self, 'fetch').value].join()", "false,function");
    try expectEval(secure, "['caches' in self, typeof Object.getOwnPropertyDescriptor(self, 'fetch').value].join()", "true,function");
}
