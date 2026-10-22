//! Runners obtained during V8 initialization share the later host wake target.
const std = @import("std");
const engine = @import("engine");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;

const Probe = struct {
    ran: usize = 0,
    dropped: usize = 0,
    fn run(data: ?*anyopaque) callconv(.c) void {
        const self: *@This() = @ptrCast(@alignCast(data.?));
        self.ran += 1;
    }
    fn drop(data: ?*anyopaque) callconv(.c) void {
        const self: *@This() = @ptrCast(@alignCast(data.?));
        self.dropped += 1;
    }
    fn noop(_: ?*anyopaque) void {}
    fn wake(data: ?*anyopaque) callconv(.c) void {
        const sink: *runtime.TaskSink = @ptrCast(@alignCast(data.?));
        _ = sink.post(.{ .run = noop, .drop = noop, .data = null });
    }
    fn release(data: ?*anyopaque) callconv(.c) void {
        const sink: *runtime.TaskSink = @ptrCast(@alignCast(data.?));
        sink.release();
    }
};

fn exercise(isolate: *ffi.Isolate) !void {
    var live = true;
    defer if (live) ffi.v8_Isolate_Dispose(isolate);
    const sink = try runtime.TaskSink.create(std.testing.allocator);
    defer sink.release();
    defer sink.close();
    const runner = ffi.v8_test_ForegroundTaskRunner(isolate) orelse return error.NoInitializationRunner;
    defer ffi.v8_test_TaskRunner_Release(runner);
    var delay: u64 = undefined;
    // No context has been created and no foreground task has been posted.
    try std.testing.expect(!ffi.v8_Isolate_NextForegroundTaskDelay(isolate, &delay));
    const retained = sink.retain();
    if (!ffi.v8_Isolate_AttachForegroundTaskSink(isolate, retained, Probe.wake, Probe.release)) {
        retained.release();
        return error.AttachFailed;
    }
    var counts: Probe = .{};
    ffi.v8_test_TaskRunner_Post(runner, Probe.run, Probe.drop, &counts, 0);
    try std.testing.expect(sink.hasPosted());
    try std.testing.expect(ffi.v8_Isolate_NextForegroundTaskDelay(isolate, &delay));
    try std.testing.expectEqual(@as(u64, 0), delay);
    {
        ffi.v8_Isolate_Enter(isolate);
        defer ffi.v8_Isolate_Exit(isolate);
        while (ffi.v8_Platform_PumpMessageLoop(isolate)) {}
    }
    try std.testing.expectEqual(@as(usize, 1), counts.ran);
    ffi.v8_Isolate_CloseForegroundTasks(isolate);
    try std.testing.expect(!ffi.v8_Isolate_NextForegroundTaskDelay(isolate, &delay));
    try std.testing.expectEqual(@as(u32, 1), sink.refs.load(.acquire));
    const wake = sink.wake.load(.acquire);
    ffi.v8_Isolate_Dispose(isolate);
    live = false;
    ffi.v8_test_TaskRunner_Post(runner, Probe.run, Probe.drop, &counts, 0);
    try std.testing.expectEqual(wake, sink.wake.load(.acquire));
    try std.testing.expectEqual(@as(usize, 1), counts.ran);
    try std.testing.expectEqual(@as(usize, 2), counts.dropped);
}

fn check(comptime snapshot: bool) !void {
    if (snapshot) {
        // Snapshot flags must be selected before V8 starts; final gates run
        // this file alone so that this path is exercised, not skipped.
        if (ffi.v8_Platform_IsInitialized()) return error.SkipZigTest;
        const io = std.testing.io;
        const file = std.Io.Dir.cwd().openFile(io, "zig-out/bin/whatwg_snapshot.bin", .{}) catch return error.SkipZigTest;
        defer file.close(io);
        const bytes = try std.testing.allocator.alloc(u8, (try file.stat(io)).size);
        defer std.testing.allocator.free(bytes);
        _ = try file.readPositionalAll(io, bytes, 0);
        try engine.initializeEngine(.{ .snapshot = bytes });
        defer engine.deinitializeEngine();
        const isolate = ffi.v8_Isolate_NewFromSnapshot(bytes.ptr, @intCast(bytes.len), v8.external_references.getRuntimeExternalReferencesPtr()) orelse return error.NoSnapshotIsolate;
        try std.testing.expect(ffi.v8_Isolate_IsFromSnapshot(isolate));
        try exercise(isolate);
    } else {
        try engine.initializeEngine(.{});
        // Rejected input never allocates an isolate or retains a record.
        try std.testing.expectEqual(@as(?*ffi.Isolate, null), ffi.v8_Isolate_NewFromSnapshot("".ptr, 0, null));
        try exercise(ffi.v8_Isolate_New() orelse return error.NoIsolate);
    }
}
fn onThread(comptime snapshot: bool) !void {
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = check(snapshot);
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    try result;
}

test "snapshot initialization runner wakes a later sink and closes safely" {
    try onThread(true);
}
test "fresh initialization runner wakes a later sink and rejected snapshots allocate nothing" {
    try onThread(false);
}
