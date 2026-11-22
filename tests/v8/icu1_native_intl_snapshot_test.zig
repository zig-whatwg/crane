//! V8's own Intl and Unicode support in an agent restored from Crane's
//! snapshot - the agent every page of the browser and the WPT runner gets
//! (lane icu1; icu1_native_intl_test.zig has the same answers in agents made
//! without the snapshot, and says why).
//!
//! The snapshot generator put Crane's own Intl (the adapter's CLDR binding)
//! and its Number/Date toLocaleString methods into the snapshot's Window
//! context (interface_bindings.installSnapshotIntrinsics), so a restored page
//! had that Intl, not V8's. With ICU in the archive the snapshot's context
//! keeps V8's. And the pattern attribute, which the adapter compiles as a
//! v-flag regular expression in a utility context of the agent's
//! (engine.matchesPatternAttribute), takes Unicode property escapes.
//!
//! Every expected answer is Chrome 157's (tmp/probes/icu1/chrome-157*.json,
//! 2026-11-22). The tests run only where they are the first in their process
//! to start V8, as every snapshot test does (pattern_attribute_snapshot_test.zig
//! says why); elsewhere they skip, saying so.

const std = @import("std");
const test_process = @import("test_process.zig");
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const ffi = @import("v8").ffi;

/// The snapshot this build generated: build.zig passes its path and makes
/// the test depend on the step that writes it.
const snapshot_path = @import("test_snapshot").path;

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

const no_hooks: protocol.HostHooks = .{};

/// An agent restored from the snapshot, and a Window realm of it restored
/// from the snapshot's context. The engine holds the snapshot while it is
/// open.
const SnapshotPage = struct {
    bytes: []u8,
    agent: *protocol.Agent,
    realm: runtime.Context,

    /// Null (the test skips) when V8 was started in this process before this
    /// test.
    fn open() !?SnapshotPage {
        if (ffi.v8_Platform_IsInitialized()) {
            std.log.warn("skipping: V8 was started in this process before this test; run it in a process of its own (tests-v8 runs at batch 1; -Dlaunch-batch=1 or -Dtest-file=)", .{});
            return null;
        }
        const io = std.testing.io;
        // Missing is a failure: the build made it for this test.
        const file = try std.Io.Dir.cwd().openFile(io, snapshot_path, .{});
        defer file.close(io);
        const size = (try file.stat(io)).size;
        const bytes = try std.heap.c_allocator.alloc(u8, size);
        errdefer std.heap.c_allocator.free(bytes);
        _ = try file.readPositionalAll(io, bytes, 0);

        try test_process.startSnapshot(bytes);
        errdefer test_process.endSnapshot();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = true, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        // Restored, not made afresh (createAgent falls back to a fresh
        // isolate, with a warning, when the snapshot does not restore - which
        // would make these tests pass for the wrong reason).
        if (!ffi.v8_Isolate_IsFromSnapshot(@ptrCast(@alignCast(agent)))) return error.AgentNotRestoredFromSnapshot;
        const realm = try protocol.createWindowRealm(&.{
            .agent_cluster_cross_origin_isolated = true,
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = true,
            .timer = null,
            .origin = "https://icu.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .bytes = bytes, .agent = agent, .realm = realm };
    }

    fn close(self: SnapshotPage) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
        test_process.endSnapshot();
        std.heap.c_allocator.free(self.bytes);
    }

    /// `source`'s completion value as a string must be `expected`, and it
    /// must report nothing.
    fn expectEval(self: SnapshotPage, source: []const u8, expected: []const u8) !void {
        var reports: Reports = .{};
        const answer = try protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, std.testing.allocator, reports.reporter());
        defer std.testing.allocator.free(answer);
        try std.testing.expectEqual(@as(usize, 0), reports.count);
        try std.testing.expectEqualStrings(expected, answer);
    }
};

test "snapshot agent: a Window realm restored from the snapshot has V8's own Intl" {
    const page = (try SnapshotPage.open()) orelse return error.SkipZigTest;
    defer page.close();
    try page.expectEval(
        \\(() => {
        \\  const d = Object.getOwnPropertyDescriptor(globalThis, "Intl");
        \\  const format = Object.getOwnPropertyDescriptor(Intl.DateTimeFormat.prototype, "format");
        \\  return [d.writable, d.enumerable, d.configurable, Object.prototype.toString.call(Intl), Intl.DateTimeFormat.length,
        \\    typeof format.get, typeof Intl.DurationFormat, Intl.supportedValuesOf("timeZone").includes("Asia/Tokyo")].join();
        \\})()
    , "true,false,true,[object Intl],0,function,function,true");
    try page.expectEval(
        \\[new Intl.ListFormat("en").format(["a", "b", "c"]), ["z", "ä", "a"].sort(new Intl.Collator("sv").compare).map((c) => c.codePointAt(0)).join(" "),
        \\ (1234.5).toLocaleString("de-DE"), new Date(Date.UTC(2026, 0, 1, 15, 4, 5)).toLocaleString("en-GB", { timeZone: "UTC" }),
        \\ /\p{L}/u.test("é"), "é".normalize("NFD").length, "i".toLocaleUpperCase("tr") === "İ"].join("|")
    , "a, b, and c|97 122 228|1.234,5|01/01/2026, 15:04:05|true|2|true");
}

test "snapshot agent: a pattern attribute takes a Unicode property escape" {
    const page = (try SnapshotPage.open()) orelse return error.SkipZigTest;
    defer page.close();
    // Chrome 157: <input pattern="\p{L}+"> with "été" matches, with "1" it
    // does not (validity.patternMismatch false, then true).
    try std.testing.expect(try protocol.matchesPatternAttribute(page.realm, "\\p{L}+", "\u{e9}t\u{e9}"));
    try std.testing.expect(!try protocol.matchesPatternAttribute(page.realm, "\\p{L}+", "1"));
    try std.testing.expect(try protocol.matchesPatternAttribute(page.realm, "[\\p{L}--[a-z]]+", "\u{e9}"));
}
