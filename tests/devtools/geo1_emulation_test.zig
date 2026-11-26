//! Lane geo1: CDP Emulation.setGeolocationOverride / clearGeolocationOverride
//! and MCP `emulate { geolocation }` (Chrome 157 / chrome-devtools-mcp v1.13.0).

const std = @import("std");
const testing = std.testing;
const Harness = @import("mcp1_harness.zig").Harness;
const replay = @import("cdpr_replay.zig");
const cdp = @import("cdp_client.zig");
const browser_mod = @import("browser");
const devtools = @import("devtools");

const BrowserHost = browser_mod.BrowserHost;
const Browser = browser_mod.Browser;
const LeakChecked = replay.LeakChecked;

const CdpPage = struct {
    host: *BrowserHost,
    tab: Browser.TabId,
    server: *devtools.Server,
    client: *cdp.Client,
    target_id: []u8,
    session: []u8,
    allocator: std.mem.Allocator,

    fn open(allocator: std.mem.Allocator, url: []const u8) !CdpPage {
        const host = try BrowserHost.start(allocator, .{});
        errdefer host.stop();
        const tab = try host.createTab(.{});
        const loaded = try host.navigate(allocator, tab, url, .{ .wait = .complete, .timeout_ms = 10_000 });
        allocator.free(loaded);
        const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
        errdefer server.stop();
        var path_buf: [96]u8 = undefined;
        const client = try cdp.Client.openWebSocket(allocator, server.port, try std.fmt.bufPrint(&path_buf, "/devtools/browser/{s}", .{server.browser_id.slice()}), null);
        errdefer client.close();
        var targets = try client.call("Target.getTargets", "{}", "");
        defer targets.deinit();
        const infos = cdp.at(targets.value, "result.targetInfos").?.array.items;
        if (infos.len == 0) return error.NoTarget;
        const target_id = try allocator.dupe(u8, cdp.stringAt(infos[infos.len - 1], "targetId").?);
        errdefer allocator.free(target_id);
        var params_buf: [128]u8 = undefined;
        var attached = try client.call("Target.attachToTarget", try std.fmt.bufPrint(&params_buf, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{target_id}), "");
        defer attached.deinit();
        const session = try allocator.dupe(u8, cdp.stringAt(attached.value, "result.sessionId").?);
        return .{ .host = host, .tab = tab, .server = server, .client = client, .target_id = target_id, .session = session, .allocator = allocator };
    }

    fn close(self: *CdpPage) void {
        self.allocator.free(self.session);
        self.allocator.free(self.target_id);
        self.client.close();
        self.server.stop();
        self.host.stop();
    }

    const OverrideSnapshot = union(enum) {
        none,
        position_unavailable,
        coordinates: struct {
            latitude: f64,
            longitude: f64,
            accuracy: f64,
            altitude: ?f64,
            altitude_accuracy: ?f64,
            heading: ?f64,
            speed: ?f64,
        },
    };

    fn readOverride(self: *CdpPage) !OverrideSnapshot {
        const Read = struct {
            tab: Browser.TabId,
            result: OverrideSnapshot = .none,
            fn run(ctx: ?*anyopaque, b: *Browser) void {
                const read: *@This() = @ptrCast(@alignCast(ctx.?));
                var found_bc: ?@TypeOf(b.current_context.?.browsing_context.?) = null;
                for (b.tabs.items) |tab_ctx| {
                    if (tab_ctx.browsing_context) |bc| {
                        if (bc.id == read.tab) {
                            found_bc = bc;
                            break;
                        }
                    }
                }
                if (found_bc == null) {
                    if (b.current_context) |c| found_bc = c.browsing_context;
                }
                const top = if (found_bc) |bc| bc.getTop() else return;
                const geo = top.host_overrides.geolocation orelse {
                    read.result = .none;
                    return;
                };
                read.result = switch (geo) {
                    .position_unavailable => .position_unavailable,
                    .coordinates => |coords| .{ .coordinates = .{
                        .latitude = coords.latitude,
                        .longitude = coords.longitude,
                        .accuracy = coords.accuracy,
                        .altitude = coords.altitude,
                        .altitude_accuracy = coords.altitude_accuracy,
                        .heading = coords.heading,
                        .speed = coords.speed,
                    } },
                };
            }
        };
        var read: Read = .{ .tab = self.tab };
        try self.host.call(&read, Read.run);
        return read.result;
    }
};

test "CDP Emulation.setGeolocationOverride sets coordinates, handles {} as POSITION_UNAVAILABLE, clears on clearGeolocationOverride and detach" {
    var gpa = LeakChecked.init;
    defer testing.expectEqual(.ok, gpa.deinit()) catch {};
    const allocator = gpa.allocator();

    var page = try CdpPage.open(allocator, "data:text/html,<title>Geo1</title>");
    defer page.close();

    // Initially no override is active.
    try testing.expectEqual(CdpPage.OverrideSnapshot.none, try page.readOverride());

    // Valid override with optional fields.
    {
        var resp = try page.client.call(
            "Emulation.setGeolocationOverride",
            "{\"latitude\":37.7749,\"longitude\":-122.4194,\"accuracy\":10,\"altitude\":15.5,\"altitudeAccuracy\":2.5,\"heading\":90,\"speed\":3.2}",
            page.session,
        );
        defer resp.deinit();
        try testing.expect(cdp.at(resp.value, "error") == null);
    }
    switch (try page.readOverride()) {
        .coordinates => |c| {
            try testing.expectApproxEqAbs(@as(f64, 37.7749), c.latitude, 1e-9);
            try testing.expectApproxEqAbs(@as(f64, -122.4194), c.longitude, 1e-9);
            try testing.expectApproxEqAbs(@as(f64, 10.0), c.accuracy, 1e-9);
            try testing.expectApproxEqAbs(@as(f64, 15.5), c.altitude.?, 1e-9);
            try testing.expectApproxEqAbs(@as(f64, 2.5), c.altitude_accuracy.?, 1e-9);
            try testing.expectApproxEqAbs(@as(f64, 90.0), c.heading.?, 1e-9);
            try testing.expectApproxEqAbs(@as(f64, 3.2), c.speed.?, 1e-9);
        },
        else => return error.ExpectedCoordinatesOverride,
    }

    // Empty params `{}` emulates POSITION_UNAVAILABLE (Chrome EmulationHandler).
    {
        var resp = try page.client.call("Emulation.setGeolocationOverride", "{}", page.session);
        defer resp.deinit();
        try testing.expect(cdp.at(resp.value, "error") == null);
    }
    try testing.expectEqual(CdpPage.OverrideSnapshot.position_unavailable, try page.readOverride());

    // Omitted accuracy also emulates POSITION_UNAVAILABLE.
    {
        var resp = try page.client.call("Emulation.setGeolocationOverride", "{\"latitude\":52.5,\"longitude\":13.4}", page.session);
        defer resp.deinit();
        try testing.expect(cdp.at(resp.value, "error") == null);
    }
    try testing.expectEqual(CdpPage.OverrideSnapshot.position_unavailable, try page.readOverride());

    // Out-of-range coordinates emulate POSITION_UNAVAILABLE.
    {
        var resp = try page.client.call("Emulation.setGeolocationOverride", "{\"latitude\":95,\"longitude\":10,\"accuracy\":1}", page.session);
        defer resp.deinit();
        try testing.expect(cdp.at(resp.value, "error") == null);
    }
    try testing.expectEqual(CdpPage.OverrideSnapshot.position_unavailable, try page.readOverride());

    // clearGeolocationOverride restores no override (platform source again).
    {
        var resp = try page.client.call("Emulation.clearGeolocationOverride", "{}", page.session);
        defer resp.deinit();
        try testing.expect(cdp.at(resp.value, "error") == null);
    }
    try testing.expectEqual(CdpPage.OverrideSnapshot.none, try page.readOverride());

    // Re-apply override, then detach session -> sessionEnded clears the override.
    {
        var resp = try page.client.call("Emulation.setGeolocationOverride", "{\"latitude\":51.5,\"longitude\":-0.12,\"accuracy\":0}", page.session);
        defer resp.deinit();
        try testing.expect(cdp.at(resp.value, "error") == null);
    }
    switch (try page.readOverride()) {
        .coordinates => |c| {
            try testing.expectApproxEqAbs(@as(f64, 51.5), c.latitude, 1e-9);
            try testing.expectApproxEqAbs(@as(f64, -0.12), c.longitude, 1e-9);
            try testing.expectApproxEqAbs(@as(f64, 0.0), c.accuracy, 1e-9);
        },
        else => return error.ExpectedCoordinatesOverride,
    }
    {
        var params_buf: [128]u8 = undefined;
        var resp = try page.client.call("Target.detachFromTarget", try std.fmt.bufPrint(&params_buf, "{{\"sessionId\":\"{s}\"}}", .{page.session}), "");
        defer resp.deinit();
        try testing.expect(cdp.at(resp.value, "error") == null);
    }
    try testing.expectEqual(CdpPage.OverrideSnapshot.none, try page.readOverride());
}

test "MCP emulate geolocation: applies, formats in McpResponse order, persists, clears, and validates bounds" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();

    var r = try h.tool("emulate", "{\"pageId\":1,\"geolocation\":\"37.7749,-122.4194\"}");
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings(
        "Emulation configured successfully\nEmulating geolocation: latitude=37.7749, longitude=-122.4194",
        r.text,
    );

    // Persists on subsequent page tool calls.
    r = try h.tool("list_console_messages", "{\"pageId\":1}");
    try testing.expect(!r.is_error);
    try testing.expect(std.mem.indexOf(u8, r.text, "Emulating geolocation: latitude=37.7749, longitude=-122.4194") != null);

    // Combined emulation lines follow McpResponse order: network, geolocation, viewport, UA, CPU.
    r = try h.tool("emulate", "{\"pageId\":1,\"networkConditions\":\"Slow 3G\",\"geolocation\":\"52.5,13.4\",\"viewport\":\"400x300\",\"userAgent\":\"Agent/3\",\"cpuThrottlingRate\":4}");
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings(
        \\Emulation configured successfully
        \\Emulating network conditions: Slow 3G
        \\Default navigation timeout set to 400000 ms
        \\Emulating geolocation: latitude=52.5, longitude=13.4
        \\Emulating viewport: {"isMobile":false,"hasTouch":false,"isLandscape":false,"width":400,"height":300}
        \\Emulating user agent: Agent/3
        \\Emulating CPU throttling: 4x slowdown
    ,
        r.text,
    );

    // Empty string clears geolocation.
    r = try h.tool("emulate", "{\"pageId\":1,\"geolocation\":\"\"}");
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings("Emulation configured successfully", r.text);

    // Boundary values (-90, 180) are accepted, and omitting geolocation clears it.
    r = try h.tool("emulate", "{\"pageId\":1,\"geolocation\":\"-90,180\"}");
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings("Emulation configured successfully\nEmulating geolocation: latitude=-90, longitude=180", r.text);

    r = try h.tool("emulate", "{\"pageId\":1}");
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings("Emulation configured successfully", r.text);

    // Validation errors.
    r = try h.tool("emulate", "{\"pageId\":1,\"geolocation\":\"95,10\"}");
    try testing.expect(r.is_error);
    try testing.expectEqualStrings("Input validation error: Invalid arguments for tool emulate: geolocation.latitude: Too big: expected number to be <=90", r.text);

    r = try h.tool("emulate", "{\"pageId\":1,\"geolocation\":\"10,-200\"}");
    try testing.expect(r.is_error);
    try testing.expectEqualStrings("Input validation error: Invalid arguments for tool emulate: geolocation.longitude: Too small: expected number to be >=-180", r.text);
}
