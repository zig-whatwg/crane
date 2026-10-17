//! Agents restored from the engine's snapshot read its blob in place: no
//! copy per agent, and no agent left reading it when the engine forgets it.
//!
//! v8_Isolate_NewFromSnapshot copied the 2.6 MB blob into a `new char[]`, and
//! a `new StartupData` around it, for every isolate it made, and nothing ever
//! freed either - one leak per Browser, and one per every Browser the WPT
//! runner starts afresh after a file that leaves a service worker
//! registration (lane sw1-b3's leaks --atExit: 5 -> 98 roots over fetch/api/;
//! lesson testing-a-leak-total-that-grows-with-the-browsers-a-run-makes-is-a-
//! per-browser-leak). The blob the engine was given is already the process's
//! (crane.Process reads it once and frees it after its last Browser), and the
//! protocol lends it until deinitializeEngine, which comes after every agent
//! is destroyed - as Chromium hands every isolate the one mapped snapshot
//! (gin/v8_initializer.cc: GetMappedFileData points the StartupData into
//! g_mapped_snapshot, "never freed nor closed").
//!
//! The snapshot is the one this build generates, zig-out/bin/whatwg_snapshot.bin
//! (the `snapshot` step; `wpt-runner` depends on it). Without it the test is
//! skipped. It runs only where this file is the first in its process to start
//! V8, for pattern_attribute_snapshot_test.zig's reason: in tests/v8's shared
//! executable it skips, saying so; it runs under `-Dtest-file=` and
//! `-Dtest-isolation=file`.

const std = @import("std");
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const v8 = @import("v8");
const ffi = v8.ffi;

const snapshot_path = "zig-out/bin/whatwg_snapshot.bin";

const no_hooks: protocol.HostHooks = .{};

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) protocol.Reporter {
        return .{ .report = report, .host = self };
    }
};

/// Whether `source`, run in `realm`, is true.
fn holds(realm: runtime.Context, source: []const u8) !bool {
    var reports: Reports = .{};
    const held = try protocol.evaluateClassicScript(realm, .{ .utf8 = source }, "", null, reports.reporter());
    defer held.release();
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    return protocol.toBoolean(realm, held.value);
}

test "agents restored from the snapshot read the engine's blob in place, and all end before it does" {
    if (ffi.v8_Platform_IsInitialized()) {
        std.log.warn("skipping: V8 was started in this process before this file; run it with -Dtest-file= or -Dtest-isolation=file", .{});
        return error.SkipZigTest;
    }
    const io = std.testing.io;
    const file = std.Io.Dir.cwd().openFile(io, snapshot_path, .{}) catch |err| {
        std.log.warn("skipping: no snapshot at {s} ({s}); `zig build snapshot` makes it", .{ snapshot_path, @errorName(err) });
        return error.SkipZigTest;
    };
    const bytes = blk: {
        defer file.close(io);
        const size = (try file.stat(io)).size;
        const bytes = try std.heap.c_allocator.alloc(u8, size);
        errdefer std.heap.c_allocator.free(bytes);
        _ = try file.readPositionalAll(io, bytes, 0);
        break :blk bytes;
    };
    // Freed last: after the engine has forgotten it, which is after every
    // agent restored from it was destroyed.
    defer std.heap.c_allocator.free(bytes);
    try protocol.initializeEngine(.{ .snapshot = bytes });
    defer protocol.deinitializeEngine();
    if (runtime.BrowserScope.standalone() == null) runtime.initializeRuntime(std.heap.page_allocator);
    interfaces.process_hooks.startHooksForTest();

    // V8's bytes are the file's less the build stamp at its end
    // (snapshot_loader.splitStamp), so they start where the file does.
    const blob_len = bytes.len - v8.snapshot_loader.stamp_len;
    const live_before = v8.protocol_agents.liveSnapshotAgents();

    for (0..4) |_| {
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = true, .hooks = &no_hooks, .host = null });
        defer protocol.destroyAgent(agent);
        const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
        // Restored, not made afresh (createAgent falls back to a fresh
        // isolate, with a warning, when the snapshot does not restore).
        try std.testing.expect(ffi.v8_Isolate_IsFromSnapshot(isolate));
        try std.testing.expectEqual(live_before + 1, v8.protocol_agents.liveSnapshotAgents());

        // In place: the bytes V8 restores this isolate from are the engine's
        // blob itself, not a copy of it.
        var restored_len: usize = 0;
        const restored = ffi.v8_Isolate_SnapshotBlob(isolate, &restored_len) orelse return error.NoSnapshotBlob;
        try std.testing.expectEqual(@intFromPtr(bytes.ptr), @intFromPtr(restored));
        try std.testing.expectEqual(blob_len, restored_len);

        // V8 reads the blob again for every context restored from it
        // (Snapshot::NewContextFromSnapshot), long after the isolate was
        // made: a Window realm restored now still comes from those bytes.
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = true,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        defer protocol.destroyWindowRealm(realm, .global_detached);
        try std.testing.expect(try holds(realm, "globalThis instanceof Window && typeof Document === 'function'"));
    }

    // Every agent restored from the blob has ended, so the engine may let go
    // of it and the host free it.
    try std.testing.expectEqual(live_before, v8.protocol_agents.liveSnapshotAgents());
}
