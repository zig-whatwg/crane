//! Exercise Resource Timing's real toJSON binding, including its cached
//! Server-Timing array, then measure V8's live handles after repeated calls.
//! WPT covers JSON surviving collection after its resource entry is dropped.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const timeline = @import("dom").performance_timeline;
const ffi = @import("v8").ffi;

const Trial = struct {
    result: anyerror!void = {},

    fn run(self: *Trial) void {
        self.result = self.check();
    }

    fn global(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(std.testing.allocator, realm) catch null;
    }

    fn report(_: ?*anyopaque, info: *const engine.ErrorInfo) void {
        std.debug.print("Resource JSON test: {s}\n", .{info.message});
    }

    fn expectScript(realm: runtime.Context, source: []const u8) !void {
        const answer = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, std.testing.allocator, .{ .report = report });
        defer std.testing.allocator.free(answer);
        try std.testing.expectEqualStrings("ok", answer);
    }

    fn check(_: *Trial) !void {
        // A fresh thread owns all per-thread runtime state. Never change
        // V8 flags: another tests/v8 file may already have started V8.
        try engine.initializeEngine(.{});
        runtime.initializeRuntime(std.testing.allocator);
        defer runtime.deinitializeRuntime();
        interfaces.process_hooks.startHooksForTest();
        var scope = runtime.BrowserScope.init(std.testing.allocator);
        defer scope.deinit();
        const hooks: engine.HostHooks = .{};
        const agent = try engine.createAgent(.{
            .can_block = false,
            .from_snapshot = false,
            .hooks = &hooks,
            .allocator = std.testing.allocator,
        });
        defer engine.destroyAgent(agent);
        const realm = try engine.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.testing.allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .browser_scope = &scope,
            .create_global_object = global,
        });
        defer engine.destroyWindowRealm(realm, .global_detached);
        try expectScript(realm, "void performance; 'ok'");

        var fixture: Fixture = .{ .realm = realm };
        try engine.runInRealm(realm, Fixture.install, &fixture);
        try fixture.result;

        // Both branches of get_serverTiming: first create the array, then
        // read the entry's traced array on each following toJSON call.
        const body =
            \\(() => {
            \\  const entries = performance.getEntriesByType('resource');
            \\  if (entries.length !== 2) throw Error('missing fixtures');
            \\  for (let i = 0; i < 2000; ++i) {
            \\    const full = entries[0].toJSON().serverTiming;
            \\    const empty = entries[1].toJSON().serverTiming;
            \\    if (!Array.isArray(full) || full.length !== 1 ||
            \\        full[0].name !== 'db' || full[0].duration !== 12.5 ||
            \\        full[0].description !== 'cached' ||
            \\        !Array.isArray(empty) || empty.length !== 0)
            \\      throw Error('toJSON must include serverTiming');
            \\  }
            \\  return 'ok';
            \\})()
        ;
        try expectScript(realm, body);
        try collect(realm, agent);
        const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
        const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        try expectScript(realm, body);
        try collect(realm, agent);
        const after = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        // One hold leaked per entry/call would add >=64 KiB. Leave only
        // the same small table-bookkeeping margin as the returned-dictionary test.
        if (after -| before >= 16 * 1024) {
            std.debug.print("4000 Resource JSON calls retained {d} handle bytes\n", .{after -| before});
            return error.HandlesKept;
        }
    }

    fn collect(realm: runtime.Context, agent: *engine.Agent) !void {
        const Collect = struct {
            fn run(raw: ?*anyopaque) void {
                engine.requestGarbageCollection(@ptrCast(@alignCast(raw.?)));
            }
        };
        try engine.runInRealm(realm, Collect.run, agent);
        try engine.runInRealm(realm, Collect.run, agent);
    }
};

const Fixture = struct {
    realm: runtime.Context,
    result: anyerror!void = {},

    fn install(raw: ?*anyopaque) void {
        const self: *Fixture = @ptrCast(@alignCast(raw.?));
        self.result = self.makeEntries();
    }

    fn makeEntries(self: *Fixture) !void {
        // markResourceTiming copies the fixture's scalar data and strings.
        // It owns the new entries through the normal timeline buffer.
        var timing: timeline.ResourceTiming = .{
            .allocator = std.testing.allocator,
            .url = @constCast("https://example.test/full"),
            .initiator_type = "fetch",
            .delivery_type = "",
            .cache_mode = .none,
            .response_status = 200,
            .render_blocking = false,
            .start_time = 1,
            .end_time = 2,
            .worker_start = 0,
            .redirect_start = 0,
            .redirect_end = 0,
            .fetch_start = 1,
            .domain_lookup_start = 1,
            .domain_lookup_end = 1,
            .connect_start = 1,
            .connect_end = 1,
            .secure_connection_start = 0,
            .request_start = 1,
            .final_response_headers_start = 2,
            .first_interim_response_start = 0,
            .response_end = 2,
            .next_hop_protocol = @constCast(""),
            .encoded_body_size = 0,
            .decoded_body_size = 0,
            .content_type = @constCast(""),
            .content_encoding = @constCast(""),
        };
        const Metric = std.meta.Child(@TypeOf(timing.server_timing));
        var metrics = [_]Metric{.{ .name = @constCast("db"), .duration = 12.5, .description = @constCast("cached") }};
        timing.server_timing = &metrics;
        try timeline.markResourceTiming(self.realm, &timing);
        timing.url = @constCast("https://example.test/empty");
        timing.start_time = 3;
        timing.end_time = 4;
        timing.fetch_start = 3;
        timing.domain_lookup_start = 3;
        timing.domain_lookup_end = 3;
        timing.connect_start = 3;
        timing.connect_end = 3;
        timing.request_start = 3;
        timing.final_response_headers_start = 4;
        timing.response_end = 4;
        timing.server_timing = &.{};
        try timeline.markResourceTiming(self.realm, &timing);
    }
};

test "Resource Timing toJSON hands over its full and empty metric arrays without retaining handles" {
    var trial: Trial = .{};
    const thread = try std.Thread.spawn(.{}, Trial.run, .{&trial});
    thread.join();
    try trial.result;
}
