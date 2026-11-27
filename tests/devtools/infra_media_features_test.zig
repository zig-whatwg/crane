//! Lane infra-ci1: CDP Emulation.setEmulatedMedia remaining Media Queries 5
//! features (`prefers-reduced-transparency`, `inverted-colors`, `color-gamut`,
//! `dynamic-range`, `prefers-reduced-data`).

const std = @import("std");
const testing = std.testing;
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

    fn evalBool(self: *CdpPage, expr: []const u8) !bool {
        var buf: [512]u8 = undefined;
        const params = try std.fmt.bufPrint(&buf, "{{\"expression\":\"{s}\",\"returnByValue\":true}}", .{expr});
        var res = try self.client.call("Runtime.evaluate", params, self.session);
        defer res.deinit();
        const val = cdp.at(res.value, "result.result.value") orelse return error.MissingResult;
        return switch (val) {
            .bool => |b| b,
            else => error.UnexpectedResultType,
        };
    }

    fn evalString(self: *CdpPage, allocator: std.mem.Allocator, expr: []const u8) ![]u8 {
        var buf: [512]u8 = undefined;
        const params = try std.fmt.bufPrint(&buf, "{{\"expression\":\"{s}\",\"returnByValue\":true}}", .{expr});
        var res = try self.client.call("Runtime.evaluate", params, self.session);
        defer res.deinit();
        const s = cdp.stringAt(res.value, "result.result.value") orelse return error.MissingResult;
        return allocator.dupe(u8, s);
    }

    fn setFeatures(self: *CdpPage, features_json: []const u8) !void {
        var buf: [1024]u8 = undefined;
        const params = try std.fmt.bufPrint(&buf, "{{\"features\":{s}}}", .{features_json});
        var res = try self.client.call("Emulation.setEmulatedMedia", params, self.session);
        defer res.deinit();
        try testing.expect(cdp.at(res.value, "error") == null);
    }
};

test "CDP Emulation.setEmulatedMedia supports prefers-reduced-transparency, inverted-colors, and prefers-reduced-data" {
    var gpa = LeakChecked.init;
    defer testing.expectEqual(.ok, gpa.deinit()) catch {};
    const allocator = gpa.allocator();

    var page = try CdpPage.open(allocator, "data:text/html,<style>.box{color:rgb(1,1,1)}@media(prefers-reduced-transparency:reduce){.box{color:rgb(2,2,2)}}@media(inverted-colors:inverted){.box{background-color:rgb(3,3,3)}}@media(prefers-reduced-data:reduce){.box{border-top-color:rgb(4,4,4)}}</style><div id=box class=box></div>");
    defer page.close();

    // Defaults (MQ5 §12.2, §6.6, §12.6)
    try testing.expect(try page.evalBool("matchMedia('(prefers-reduced-transparency: no-preference)').matches"));
    try testing.expect(!try page.evalBool("matchMedia('(prefers-reduced-transparency: reduce)').matches"));
    try testing.expect(!try page.evalBool("matchMedia('(prefers-reduced-transparency)').matches"));

    try testing.expect(try page.evalBool("matchMedia('(inverted-colors: none)').matches"));
    try testing.expect(!try page.evalBool("matchMedia('(inverted-colors: inverted)').matches"));
    try testing.expect(!try page.evalBool("matchMedia('(inverted-colors)').matches"));

    try testing.expect(try page.evalBool("matchMedia('(prefers-reduced-data: no-preference)').matches"));
    try testing.expect(!try page.evalBool("matchMedia('(prefers-reduced-data: reduce)').matches"));
    try testing.expect(!try page.evalBool("matchMedia('(prefers-reduced-data)').matches"));

    // Emulate all three active
    try page.setFeatures(
        \\[{"name":"prefers-reduced-transparency","value":"reduce"},{"name":"inverted-colors","value":"inverted"},{"name":"prefers-reduced-data","value":"reduce"}]
    );

    try testing.expect(try page.evalBool("matchMedia('(prefers-reduced-transparency: reduce)').matches"));
    try testing.expect(!try page.evalBool("matchMedia('(prefers-reduced-transparency: no-preference)').matches"));
    try testing.expect(try page.evalBool("matchMedia('(prefers-reduced-transparency)').matches"));

    try testing.expect(try page.evalBool("matchMedia('(inverted-colors: inverted)').matches"));
    try testing.expect(!try page.evalBool("matchMedia('(inverted-colors: none)').matches"));
    try testing.expect(try page.evalBool("matchMedia('(inverted-colors)').matches"));

    try testing.expect(try page.evalBool("matchMedia('(prefers-reduced-data: reduce)').matches"));
    try testing.expect(!try page.evalBool("matchMedia('(prefers-reduced-data: no-preference)').matches"));
    try testing.expect(try page.evalBool("matchMedia('(prefers-reduced-data)').matches"));

    const color = try page.evalString(allocator, "getComputedStyle(document.getElementById('box')).color");
    defer allocator.free(color);
    try testing.expectEqualStrings("rgb(2, 2, 2)", color);
    const bg = try page.evalString(allocator, "getComputedStyle(document.getElementById('box')).backgroundColor");
    defer allocator.free(bg);
    try testing.expectEqualStrings("rgb(3, 3, 3)", bg);
    const border = try page.evalString(allocator, "getComputedStyle(document.getElementById('box')).borderTopColor");
    defer allocator.free(border);
    try testing.expectEqualStrings("rgb(4, 4, 4)", border);

    // Clear overrides with empty values
    try page.setFeatures(
        \\[{"name":"prefers-reduced-transparency","value":""},{"name":"inverted-colors","value":""},{"name":"prefers-reduced-data","value":""}]
    );
    try testing.expect(try page.evalBool("matchMedia('(prefers-reduced-transparency: no-preference)').matches"));
    try testing.expect(try page.evalBool("matchMedia('(inverted-colors: none)').matches"));
    try testing.expect(try page.evalBool("matchMedia('(prefers-reduced-data: no-preference)').matches"));
}

test "CDP Emulation.setEmulatedMedia supports color-gamut and dynamic-range ascending semantics and resets on detach" {
    var gpa = LeakChecked.init;
    defer testing.expectEqual(.ok, gpa.deinit()) catch {};
    const allocator = gpa.allocator();

    var page = try CdpPage.open(allocator, "data:text/html,<title>Gamut</title>");
    defer page.close();

    // Defaults: color-gamut=srgb (MQ5 §6.4), dynamic-range=standard (MQ5 §6.5)
    try testing.expect(try page.evalBool("matchMedia('(color-gamut)').matches"));
    try testing.expect(try page.evalBool("matchMedia('(color-gamut: srgb)').matches"));
    try testing.expect(!try page.evalBool("matchMedia('(color-gamut: p3)').matches"));
    try testing.expect(!try page.evalBool("matchMedia('(color-gamut: rec2020)').matches"));
    try testing.expect(!try page.evalBool("matchMedia('(color-gamut: invalid)').matches"));
    try testing.expect(!try page.evalBool("matchMedia('not (color-gamut: invalid)').matches"));

    try testing.expect(try page.evalBool("matchMedia('(dynamic-range)').matches"));
    try testing.expect(try page.evalBool("matchMedia('(dynamic-range: standard)').matches"));
    try testing.expect(!try page.evalBool("matchMedia('(dynamic-range: high)').matches"));

    // color-gamut: p3 matches both srgb and p3 (MQ5 §6.4); dynamic-range: high matches both standard and high (MQ5 §6.5)
    try page.setFeatures(
        \\[{"name":"color-gamut","value":"p3"},{"name":"dynamic-range","value":"high"}]
    );
    try testing.expect(try page.evalBool("matchMedia('(color-gamut: srgb)').matches"));
    try testing.expect(try page.evalBool("matchMedia('(color-gamut: p3)').matches"));
    try testing.expect(!try page.evalBool("matchMedia('(color-gamut: rec2020)').matches"));
    try testing.expect(try page.evalBool("matchMedia('(dynamic-range: standard)').matches"));
    try testing.expect(try page.evalBool("matchMedia('(dynamic-range: high)').matches"));

    // color-gamut: rec2020 matches srgb, p3, and rec2020
    try page.setFeatures(
        \\[{"name":"color-gamut","value":"rec2020"},{"name":"dynamic-range","value":"standard"}]
    );
    try testing.expect(try page.evalBool("matchMedia('(color-gamut: srgb)').matches"));
    try testing.expect(try page.evalBool("matchMedia('(color-gamut: p3)').matches"));
    try testing.expect(try page.evalBool("matchMedia('(color-gamut: rec2020)').matches"));
    try testing.expect(try page.evalBool("matchMedia('(dynamic-range: standard)').matches"));
    try testing.expect(!try page.evalBool("matchMedia('(dynamic-range: high)').matches"));

    // Detach session -> overrides revert to defaults when a fresh session attaches
    var detach_buf: [128]u8 = undefined;
    var detached = try page.client.call("Target.detachFromTarget", try std.fmt.bufPrint(&detach_buf, "{{\"sessionId\":\"{s}\"}}", .{page.session}), "");
    detached.deinit();

    var attach_buf: [128]u8 = undefined;
    var attached2 = try page.client.call("Target.attachToTarget", try std.fmt.bufPrint(&attach_buf, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{page.target_id}), "");
    defer attached2.deinit();
    allocator.free(page.session);
    page.session = try allocator.dupe(u8, cdp.stringAt(attached2.value, "result.sessionId").?);

    try testing.expect(try page.evalBool("matchMedia('(color-gamut: srgb)').matches"));
    try testing.expect(!try page.evalBool("matchMedia('(color-gamut: p3)').matches"));
    try testing.expect(!try page.evalBool("matchMedia('(color-gamut: rec2020)').matches"));
}
