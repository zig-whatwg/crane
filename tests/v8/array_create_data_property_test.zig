//! An Array the engine builds gets its elements by CreateDataProperty, never
//! by [[Set]]: a setter script put on Array.prototype never runs.
//!
//! WebIDL 3.2.28 (sequence<T> to ECMAScript): "Perform !
//! CreateDataPropertyOrThrow(A, P, E)". `v8_Array_Set` - which every array
//! the adapter builds goes through (createSequenceOfValues, sequence results,
//! frozen arrays, iterator entries, Intl's lists) - did a [[Set]], and V8's
//! Array::Set on a hole walks the prototype chain: an `Array.prototype[0]`
//! setter ran and the element was never defined
//! (IndexedDB/bindings-inject-keys-bypass, codex-indexeddb Q39).

const std = @import("std");
const test_process = @import("test_process.zig");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");

/// The hooks of the file's agent: none.
const window_agent_hooks: protocol.HostHooks = .{};
const interfaces = @import("interfaces");

var test_isolate: ?*ffi.Isolate = null;
/// The test's own agent, ended with the test (test_process.TestAgent);
/// `reset` clears what the file caches of it.
var test_agent: test_process.TestAgent = .{ .reset = reset };

fn reset() void {
    test_isolate = null;
}

/// The file's agent, made once and current while the calling test runs.
fn agent() !*ffi.Isolate {
    const i = try test_agent.open(.{ .hooks = &window_agent_hooks });
    if (test_isolate == null) {
        const context = test_agent.context.?;
        _ = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
        test_isolate = i;
    }
    return test_isolate.?;
}

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

fn windowRealm() !runtime.Context {
    const isolate = try agent();
    return protocol.createWindowRealm(&.{
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
}

const Ignored = struct {
    fn report(_: ?*anyopaque, _: *const protocol.ErrorInfo) void {}
    const reporter: protocol.Reporter = .{ .report = report, .host = null };
};

fn run(r: runtime.Context, source: []const u8) !void {
    try protocol.runClassicScript(r, .{ .utf8 = source }, "", null, Ignored.reporter);
}

fn expectEval(r: runtime.Context, source: []const u8, expected: []const u8) !void {
    const got = try protocol.evaluateClassicScriptToString(r, .{ .utf8 = source }, "", null, std.testing.allocator, Ignored.reporter);
    defer std.testing.allocator.free(got);
    try std.testing.expectEqualStrings(expected, got);
}

const poison =
    \\globalThis.poisoned = 0;
    \\for (const i of [0, 1]) Object.defineProperty(Array.prototype, i, {
    \\  set(v) { globalThis.poisoned++; }, get() { return "from the prototype"; }, configurable: true,
    \\});
;

const unpoison = "delete Array.prototype[0]; delete Array.prototype[1];";

test "a sequence of values is an Array whose elements are its own data properties" {
    defer test_agent.close();
    const page = try windowRealm();
    defer protocol.destroyWindowRealm(page, .global_detached);
    try run(page, poison);
    defer run(page, unpoison) catch {};

    const sequence = try protocol.createSequenceOfValues(page, &.{ runtime.JSValue.fromNumber(7), runtime.JSValue.fromNumber(8) });
    defer sequence.release();
    const global = try protocol.evaluateClassicScript(page, .{ .utf8 = "globalThis" }, "", null, Ignored.reporter);
    defer global.release();
    try protocol.defineOwnProperty(page, global.value, "sequence", sequence.value, .{ .writable = true, .enumerable = false, .configurable = true });

    try expectEval(page, "String(poisoned)", "0");
    try expectEval(page, "sequence.length + ':' + sequence[0] + ':' + sequence[1]", "2:7:8");
    try expectEval(page, "const d = Object.getOwnPropertyDescriptor(sequence, 0); String(d.value === 7 && d.writable && d.enumerable && d.configurable)", "true");
}
