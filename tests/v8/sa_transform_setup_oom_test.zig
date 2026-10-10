//! The §9.3 native transformer belongs to setUp from the call onward.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const v8 = @import("v8");
const st = @import("impls").TransformStream.streams_transform;
const ffi = v8.ffi;
const testing = std.testing;
const Realm = @typeInfo(@TypeOf(st.setUp)).@"fn".params[0].type.?;
const TransformFn = @typeInfo(@FieldType(st.Transformer.VTable, "transform")).pointer.child;
const Value = @typeInfo(TransformFn).@"fn".params[3].type.?;
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
        // A fresh thread gives each trial its own per-thread pools/manager.
        // No V8 flags change, and no entered isolate escapes the test.
        const isolate = ffi.v8_Isolate_New() orelse return error.NoIsolate;
        defer ffi.v8_Isolate_Dispose(isolate);
        ffi.v8_Isolate_Enter(isolate);
        defer ffi.v8_Isolate_Exit(isolate);
        const scope = ffi.v8_HandleScope_New(isolate);
        defer if (scope) |s| ffi.v8_HandleScope_Dispose(s);
        try v8.isolate_allocator.initIsolateAllocator(isolate, testing.allocator, false);
        defer {
            // Raw FFI isolate disposal does not perform the adapter's
            // cleanup. Match destroyAgent's isolate-scoped order, so reused
            // isolate addresses cannot find an earlier trial's templates.
            v8.cleanupTemplateStorage(isolate, testing.allocator);
            v8.template_registry.clearForIsolate(isolate);
            v8.isolate_allocator.deinitIsolateAllocator(isolate);
        }
        const context = ffi.v8_Context_New(isolate) orelse return error.NoContext;
        defer ffi.v8_Context_Dispose(context);
        ffi.v8_Context_Enter(context);
        defer ffi.v8_Context_Exit(context);
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(testing.allocator);
        defer runtime.deinitializeRuntime();
        var failing = testing.FailingAllocator.init(testing.allocator, .{});
        var counter: Counter = .{};
        {
            try v8.context_manager.init(testing.allocator);
            defer v8.context_manager.deinit();
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
    for (0..success.allocations) |index| {
        // Q25's scratch probe recorded each FIRST injected failure and the
        // allocation balance after context teardown. Only its leaking cache
        // failures are blocked here; balanced cache trials 2, 3 and 11, and
        // every non-cache failure, remain hard checks. Remove all exclusions
        // when rc4's adapter fix lands. A changed allocation layout must not
        // silently skip another failure.
        const blocked: ?[]const u8 = switch (index) {
            // TODO(rc4: template_registry.zig cache.set OOM): writable stream.
            5 => "wrapper_cache.zig:1624 via streams_writable.zig:1216",
            // TODO(rc4: template_registry.zig cache.set OOM): writable controller.
            7 => "wrapper_cache.zig:1624 via streams_writable.zig:879",
            // TODO(rc4: template_registry.zig cache.set OOM): AbortController.
            10 => "wrapper_cache.zig:1624 via streams_writable.zig:896",
            // TODO(rc4: template_registry.zig cache.set OOM): readable stream.
            13 => "wrapper_cache.zig:1624 via streams_readable.zig:426",
            // TODO(rc4: template_registry.zig cache.set OOM): readable controller entry.
            15 => "wrapper_cache.zig:1624 via streams_readable.zig:1033",
            // TODO(rc4: template_registry.zig cache.set OOM): readable controller map growth.
            16 => "wrapper_cache.zig:1654 hash_map.put during readable controller wrapping",
            // TODO(rc4: template_registry.zig cache.set OOM): transform controller.
            19 => "wrapper_cache.zig:1624 via streams_transform.zig:283",
            else => null,
        };
        if (blocked) |site| {
            try testing.expectEqual(@as(usize, 20), success.allocations);
            std.debug.print("BLOCKED: setUp OOM trial {d}, template_registry.zig cache.set OOM (rc4), {s}\n", .{ index, site });
            continue;
        }
        var trial: Trial = .{ .fail_after = index };
        const thread = try std.Thread.spawn(.{}, Trial.run, .{&trial});
        thread.join();
        trial.result catch |err| {
            std.debug.print("setUp allocation failure index {d}/{d}\n", .{ index, success.allocations });
            return err;
        };
    }
}
