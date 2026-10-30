//! CreateReadableByteStream's setup fails after its controller is wrapped,
//! and its source still has one owner (lane leaks1, 2026-10-29).
//!
//! fetch_body's PipeStream (Response.body) and Blob's BlobStream
//! (Blob.stream()) make their stream with CreateReadableByteStream. While
//! the call runs, each takes a busy hold on itself. On failure each marks
//! itself detached and frees itself: "a failed setup clears the source's
//! algorithms, which must not free it under this call". Before the fix,
//! createReadableByteStream did not keep that contract. A setup that failed
//! at its last step, the start promise's reaction
//! (SetUpReadableByteStreamController steps 16-17), left the WRAPPED
//! controller holding the source. The caller freed the source, and the
//! controller's teardown at the realm's end (ByteController.deinit ->
//! byteClearAlgorithms -> the source's deinit) wrote to the freed block and
//! freed it again.
//!
//! - Generation 194's sweep logged that double free once, with the traces
//!   in tmp/analysis/gen194-dfree.md: PipeStream.create's error branch, then
//!   ByteController.deinit.
//! - Lane leaks1's Debug runs saw it 3 times in 24, in
//!   FileAPI/BlobURL/cross-partition.https.html.
//! - In both, the reaction was refused because a worker's or popup's realm
//!   was ending on another thread. A test cannot time that race, so these
//!   tests refuse the reaction at the same step deterministically: they mark
//!   the realm's reaction list as ended (the V8 adapter's
//!   realm_finalizers.List.ended, which reactToPromise checks first) for the
//!   one call, while the realm and its wrappers live.
//! - The realm then ends normally, and the wrapper cache tears the
//!   controller down.
//!
//! Each test runs on a thread of its own, with a runtime, an agent and a
//! Window realm on std.testing.allocator: a second free is reported as a
//! double free, and anything the realm's end leaves is reported as leaked.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const v8 = @import("v8");

fn createGlobal(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
    return interfaces.Window.init(realm.allocator, realm) catch null;
}

fn report(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}

fn platformObject(realm: runtime.Context, source: []const u8) !*runtime.Instance {
    const value = try engine.evaluateClassicScript(realm, .{ .utf8 = source }, "leaks1-bytestream.js", null, .{ .report = report });
    defer value.release();
    return engine.convertToPlatformObject(realm, value.value) orelse error.NotAPlatformObject;
}

/// `body` in a leak-checked agent and Window realm, on a thread of its own
/// (tests/v8 is one process: the testing allocator's lock and traces must
/// not be shared with another file's agent). The realm ends after `body`.
fn inRealm(comptime body: fn (runtime.Context) anyerror!void) !void {
    const Run = struct {
        fn thread(result: *anyerror!void) void {
            result.* = check();
        }

        fn check() !void {
            try engine.initializeEngine(.{});
            runtime.initializeRuntime(std.testing.allocator);
            defer runtime.deinitializeRuntime();
            interfaces.process_hooks.startHooksForTest();
            defer dom.mutation_observer_algorithms.resetAgent();
            const hooks: engine.HostHooks = .{};
            const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooks, .allocator = std.testing.allocator });
            defer engine.destroyAgent(agent);
            const realm = try engine.createWindowRealm(&.{ .agent = agent, .allocator = std.testing.allocator, .from_snapshot = false, .timer = null, .origin = "https://leaks1.test", .create_global_object = createGlobal });
            defer engine.destroyWindowRealm(realm, .global_detached);
            try body(realm);
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&result});
    thread.join();
    try result;
}

/// Refuse (or allow again) every promise reaction in `realm`, as its end
/// does: reactToPromise answers OperationFailed while the realm's reaction
/// list says ended. Nothing else changes - the realm stays in the context
/// manager, so wraps still make wrappers.
fn refuseReactions(realm: runtime.Context, refuse: bool) !void {
    const storage = realm.getV8WrapperCacheStorage() orelse return error.NoWrapperCache;
    const cache: *v8.WrapperCache = @ptrCast(@alignCast(storage));
    cache.finalizers.ended = refuse;
}

test "Blob.stream() whose start reaction is refused after its controller is wrapped frees its source once" {
    try inRealm(struct {
        fn body(realm: runtime.Context) !void {
            const blob = try platformObject(realm, "globalThis.b = new Blob(['abc']); b");
            try refuseReactions(realm, true);
            const stream = interfaces.Blob.call_stream(blob);
            try refuseReactions(realm, false);
            // BlobStream.create's error branch freed the BlobStream; the
            // realm's end tears the wrapped controller down after this.
            try std.testing.expectError(error.V8Failure, stream);
        }
    }.body);
}

test "a Blob's stream can be made again after a refused setup" {
    try inRealm(struct {
        fn body(realm: runtime.Context) !void {
            const blob = try platformObject(realm, "globalThis.b = new Blob(['abc']); b");
            try refuseReactions(realm, true);
            const failed = interfaces.Blob.call_stream(blob);
            try refuseReactions(realm, false);
            try std.testing.expectError(error.V8Failure, failed);
            // The failed setup released its hold on the blob once: a new
            // stream holds it again, and the realm's end releases that.
            const stream = try interfaces.Blob.call_stream(blob);
            try std.testing.expect(stream != blob);
        }
    }.body);
}

test "Response.body whose start reaction is refused after its controller is wrapped frees its source once" {
    try inRealm(struct {
        fn body(realm: runtime.Context) !void {
            const response = try platformObject(realm, "globalThis.r = new Response('abc'); r");
            try refuseReactions(realm, true);
            const stream = interfaces.Response.get_body(response);
            try refuseReactions(realm, false);
            // PipeStream.create's error branch freed the PipeStream; the
            // realm's end tears the wrapped controller down after this.
            try std.testing.expectError(error.V8Failure, stream);
        }
    }.body);
}
