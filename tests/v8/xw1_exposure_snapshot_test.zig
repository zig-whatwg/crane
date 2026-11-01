//! Exercise the exposure checks with the actual generated Window snapshot.
//! Like new_global_snapshot_test, run separately when another test has
//! already initialized V8. No snapshot restore is counted as a fresh agent.
const std = @import("std");
const ffi = @import("v8").ffi;

test "xw1 snapshot Window keeps its scope while workers install their own exposed members" {
    if (ffi.v8_Platform_IsInitialized()) return error.SkipZigTest;
    const io = std.testing.io;
    // The snapshot this build generated; missing is a failure.
    const file = try std.Io.Dir.cwd().openFile(io, @import("test_snapshot").path, .{});
    defer file.close(io);
    const bytes = try std.testing.allocator.alloc(u8, (try file.stat(io)).size);
    defer std.testing.allocator.free(bytes);
    _ = try file.readPositionalAll(io, bytes, 0);
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn run(out: *anyerror!void, snapshot: []const u8) void {
            out.* = @import("xw1_exposure_test.zig").checkWithSnapshot(snapshot);
        }
    }.run, .{ &result, bytes });
    thread.join();
    try result;
}
