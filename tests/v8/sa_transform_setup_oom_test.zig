//! The §9.3 native transformer belongs to setUp from the call onward.
const std = @import("std");
const test_process = @import("test_process.zig");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const v8 = @import("v8");
const st = @import("impls").TransformStream.streams_transform;
const ffi = v8.ffi;
const testing = std.testing;
const Realm = @typeInfo(@TypeOf(st.setUp)).@"fn".param_types[0].?;
const TransformFn = @typeInfo(@FieldType(st.Transformer.VTable, "transform")).pointer.child;
const Value = @typeInfo(TransformFn).@"fn".param_types[3].?;
const Result = @typeInfo(TransformFn).@"fn".return_type.?;

const Counter = struct {
    deinits: usize = 0,

    fn transform(_: ?*anyopaque, realm: Realm, _: *runtime.Instance, _: Value) Result {
        return realm.promiseResolvedWithUndefined();
    }

    fn flush(_: ?*anyopaque, realm: Realm, _: *runtime.Instance) Result {
        return realm.promiseResolvedWithUndefined();
    }

    fn destroy(raw: ?*anyopaque, _: std.mem.Allocator) void {
        const self: *Counter = @ptrCast(@alignCast(raw.?));
        self.deinits += 1;
    }

    const vtable: st.Transformer.VTable = .{
        .transform = transform,
        .flush = flush,
        .cancel = transform,
        .deinit = destroy,
    };
};

const Trial = struct {
    fail_after: ?usize,
    allocations: usize = 0,
    result: anyerror!void = {},

    fn run(self: *Trial) void {
        self.result = self.check();
    }

    fn check(self: *Trial) !void {
        // A fresh thread gives each trial its own agent, with nothing entered.
        // No V8 flags change, and no entered isolate escapes the test.
        test_process.start();
        interfaces.process_hooks.startHooksForTest();
        // A standalone runtime of this test's own, the process's given back
        // after (test_process.OwnRuntime). It outlives the agent, whose end
        // tears the realm's objects down.
        const own_runtime = test_process.OwnRuntime.begin(testing.allocator);
        defer own_runtime.end();
        var failing = testing.FailingAllocator.init(testing.allocator, .{});
        var counter: Counter = .{};
        {
            // The agent's own state (its isolate's allocator, its realms'
            // record) through the test's allocator; its end - the realm's
            // teardown among it - at this block's end.
            const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &test_process.no_hooks, .allocator = testing.allocator });
            defer engine.destroyAgent(agent);
            const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
            ffi.v8_Isolate_Enter(isolate);
            defer ffi.v8_Isolate_Exit(isolate);
            const scope = ffi.v8_HandleScope_New(isolate);
            defer if (scope) |s| ffi.v8_HandleScope_Dispose(s);
            const context = ffi.v8_Context_New(isolate) orelse return error.NoContext;
            defer ffi.v8_Context_Dispose(context);
            ffi.v8_Context_Enter(context);
            defer ffi.v8_Context_Exit(context);
            const ctx = try v8.context_manager.getOrCreate(context, failing.allocator());
            const realm = try Realm.ofContext(ctx);
            const initial = failing.alloc_index;
            if (self.fail_after) |after| failing.fail_index = initial + after;
            const stream: ?*runtime.Instance = st.setUp(realm, ctx, .{ .ctx = &counter, .vtable = &Counter.vtable }) catch |err| blk: {
                failing.fail_index = std.math.maxInt(usize);
                // Failed setup must release the native algorithm immediately,
                // even if the wrapper cache retains its partial stream graph.
                try testing.expectEqual(@as(usize, 1), counter.deinits);
                if (self.fail_after == null) return err;
                try testing.expect(failing.has_induced_failure);
                break :blk null;
            };
            self.allocations = failing.alloc_index - initial;
            failing.fail_index = std.math.maxInt(usize);
            if (stream) |value| {
                try testing.expectEqual(@as(usize, 0), counter.deinits);
                try testing.expect(st.streamOf(value).?.controller != null);
                try testing.expect((try interfaces.TransformStream.get_readable(value)) == st.streamOf(value).?.readable.?);
                try testing.expect((try interfaces.TransformStream.get_writable(value)) == st.streamOf(value).?.writable.?);
                try testing.expect(engine.hasWrapper(value));
            }
        }
        try testing.expectEqual(@as(usize, 1), counter.deinits);
    }
};

test "native TransformStream setUp deinitializes its transformer once at every failed allocation" {
    var success: Trial = .{ .fail_after = null };
    const warm = try std.Thread.spawn(.{}, Trial.run, .{&success});
    warm.join();
    try success.result;
    try testing.expect(success.allocations > 0);
    // Every allocation fails once, a hard check each: the wrapper-cache
    // inserts too, which fail their wrap since rc4 (aa10618fb1). Whatever a
    // failed setUp built and did not wrap is freed by the step that built it.
    for (0..success.allocations) |index| {
        var trial: Trial = .{ .fail_after = index };
        const thread = try std.Thread.spawn(.{}, Trial.run, .{&trial});
        thread.join();
        trial.result catch |err| {
            std.debug.print("setUp allocation failure index {d}/{d}\n", .{ index, success.allocations });
            return err;
        };
    }
}
