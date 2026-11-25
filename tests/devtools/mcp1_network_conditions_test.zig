//! Lane mcp1, batch 4b item 7: CDP Network.overrideNetworkState,
//! Network.emulateNetworkConditionsByRule, legacy Network.emulateNetworkConditions,
//! and MCP `emulate { networkConditions }` (Offline, Slow 3G, Fast 3G, Slow 4G,
//! Fast 4G, and clearing back to unthrottled online).

const std = @import("std");
const testing = std.testing;
const Harness = @import("mcp1_harness.zig").Harness;
const replay = @import("cdpr_replay.zig");
const Site = replay.Site;
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
        var params_buf: [128]u8 = undefined;
        var attached = try client.call("Target.attachToTarget", try std.fmt.bufPrint(&params_buf, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{cdp.stringAt(infos[infos.len - 1], "targetId").?}), "");
        defer attached.deinit();
        const session = try allocator.dupe(u8, cdp.stringAt(attached.value, "result.sessionId").?);
        return .{ .host = host, .tab = tab, .server = server, .client = client, .session = session, .allocator = allocator };
    }

    fn close(self: *CdpPage) void {
        self.allocator.free(self.session);
        self.client.close();
        self.server.stop();
        self.host.stop();
    }

    fn evalJson(self: *CdpPage, expr: []const u8) ![]u8 {
        const params = try std.fmt.allocPrint(self.allocator, "{{\"expression\":{f},\"awaitPromise\":true,\"returnByValue\":true}}", .{std.json.fmt(expr, .{})});
        defer self.allocator.free(params);
        var resp = try self.client.call("Runtime.evaluate", params, self.session);
        defer resp.deinit();
        if (cdp.at(resp.value, "error") != null) return error.EvalError;
        if (cdp.at(resp.value, "result.exceptionDetails") != null) return error.EvalException;
        const val = cdp.at(resp.value, "result.result.value") orelse return try self.allocator.dupe(u8, "undefined");
        return std.fmt.allocPrint(self.allocator, "{f}", .{std.json.fmt(val, .{})});
    }
};

fn expectResult(h: *Harness, function: []const u8, json: []const u8) !void {
    const a = h.arena.allocator();
    const r = try h.tool("evaluate_script", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"function\":{f}}}", .{std.json.fmt(function, .{})}));
    try testing.expectEqualStrings(try std.fmt.allocPrint(a, "Script ran on page and returned:\n```json\n{s}\n```", .{json}), r.text);
}

test "CDP Network.overrideNetworkState toggles navigator.onLine and fires trusted offline/online events" {
    var gpa = LeakChecked.init;
    defer testing.expectEqual(.ok, gpa.deinit()) catch {};
    const allocator = gpa.allocator();

    var page = try CdpPage.open(allocator, "data:text/html,<iframe src='about:blank'></iframe>");
    defer page.close();

    var r = try page.client.call("Network.enable", "{}", page.session);
    r.deinit();
    r = try page.client.call("Runtime.enable", "{}", page.session);
    r.deinit();

    const setup = try page.evalJson(
        \\(() => {
        \\  window.__events = [];
        \\  window.addEventListener('offline', e => window.__events.push(['top', e.type, e.isTrusted, navigator.onLine]));
        \\  window.addEventListener('online', e => window.__events.push(['top', e.type, e.isTrusted, navigator.onLine]));
        \\  const f = document.querySelector('iframe').contentWindow;
        \\  f.addEventListener('offline', e => window.__events.push(['child', e.type, e.isTrusted, f.navigator.onLine]));
        \\  f.addEventListener('online', e => window.__events.push(['child', e.type, e.isTrusted, f.navigator.onLine]));
        \\  return [navigator.onLine, f.navigator.onLine];
        \\})()
    );
    defer allocator.free(setup);
    try testing.expectEqualStrings("[true,true]", setup);

    // Go offline: navigator.onLine becomes false and trusted offline fires on top + child.
    var off1 = try page.client.call("Network.overrideNetworkState", "{\"offline\":true,\"latency\":0,\"downloadThroughput\":0,\"uploadThroughput\":0}", page.session);
    defer off1.deinit();
    try testing.expect(cdp.at(off1.value, "error") == null);

    // Repeat offline: no duplicate event.
    var off2 = try page.client.call("Network.overrideNetworkState", "{\"offline\":true,\"latency\":0,\"downloadThroughput\":0,\"uploadThroughput\":0}", page.session);
    defer off2.deinit();
    try testing.expect(cdp.at(off2.value, "error") == null);

    // Back online: navigator.onLine becomes true and trusted online fires on top + child.
    var on1 = try page.client.call("Network.overrideNetworkState", "{\"offline\":false,\"latency\":0,\"downloadThroughput\":-1,\"uploadThroughput\":-1}", page.session);
    defer on1.deinit();
    try testing.expect(cdp.at(on1.value, "error") == null);

    const events = try page.evalJson("window.__events");
    defer allocator.free(events);
    try testing.expectEqualStrings(
        "[[\"top\",\"offline\",true,false],[\"child\",\"offline\",true,false],[\"top\",\"online\",true,true],[\"child\",\"online\",true,true]]",
        events,
    );
}

test "CDP Network.emulateNetworkConditionsByRule: per-URL offline, latency, download throughput, and disable cleanup" {
    var gpa = LeakChecked.init;
    defer testing.expectEqual(.ok, gpa.deinit()) catch {};
    const allocator = gpa.allocator();

    const site = try Site.start(allocator);
    defer site.stop();
    var url_buf: [128]u8 = undefined;
    const root_url = try site.url(&url_buf, "/");

    var page = try CdpPage.open(allocator, root_url);
    defer page.close();

    var r = try page.client.call("Network.enable", "{}", page.session);
    r.deinit();
    r = try page.client.call("Runtime.enable", "{}", page.session);
    r.deinit();

    // 1. Per-URL offline rule: /data.json fails with ERR_INTERNET_DISCONNECTED,
    //    /app.js still succeeds, and navigator.onLine stays true.
    var by_rule = try page.client.call(
        "Network.emulateNetworkConditionsByRule",
        "{\"matchedNetworkConditions\":[{\"urlPattern\":\"*data.json\",\"offline\":true,\"latency\":0,\"downloadThroughput\":-1,\"uploadThroughput\":-1}]}",
        page.session,
    );
    defer by_rule.deinit();
    try testing.expect(cdp.at(by_rule.value, "error") == null);
    const rule_ids = cdp.at(by_rule.value, "result.ruleIds").?.array.items;
    try testing.expectEqual(@as(usize, 1), rule_ids.len);
    try testing.expectEqual(@as(usize, 32), rule_ids[0].string.len);

    const per_url = try page.evalJson(
        \\(async () => {
        \\  const online = navigator.onLine;
        \\  let dataErr = false;
        \\  try { await fetch('/data.json'); } catch (e) { dataErr = true; }
        \\  const appStatus = (await fetch('/app.js')).status;
        \\  return [online, dataErr, appStatus];
        \\})()
    );
    defer allocator.free(per_url);
    try testing.expectEqualStrings("[true,true,200]", per_url);

    // Confirm Network.loadingFailed carried net::ERR_INTERNET_DISCONNECTED.
    var failed_ev = try page.client.waitEventOn("Network.loadingFailed", page.session);
    defer failed_ev.deinit();
    try testing.expectEqualStrings("net::ERR_INTERNET_DISCONNECTED", cdp.stringAt(failed_ev.value, "params.errorText").?);

    // 2. Latency emulation: 150 ms minimum latency measurably delays fetch.
    var lat = try page.client.call(
        "Network.emulateNetworkConditionsByRule",
        "{\"matchedNetworkConditions\":[{\"urlPattern\":\"\",\"offline\":false,\"latency\":150,\"downloadThroughput\":-1,\"uploadThroughput\":-1}]}",
        page.session,
    );
    defer lat.deinit();
    try testing.expect(cdp.at(lat.value, "error") == null);

    const t0 = std.Io.Timestamp.now(std.testing.io, .awake);
    const lat_res = try page.evalJson("(async () => (await fetch('/data.json')).status)()");
    defer allocator.free(lat_res);
    const lat_ms = t0.durationTo(std.Io.Timestamp.now(std.testing.io, .awake)).toMilliseconds();
    try testing.expectEqualStrings("200", lat_res);
    try testing.expect(lat_ms >= 120);

    // 3. Download throughput throttling: 64 KiB at 65536 B/s takes >= 350 ms.
    var dl = try page.client.call(
        "Network.emulateNetworkConditionsByRule",
        "{\"matchedNetworkConditions\":[{\"urlPattern\":\"\",\"offline\":false,\"latency\":0,\"downloadThroughput\":65536,\"uploadThroughput\":-1}]}",
        page.session,
    );
    defer dl.deinit();
    try testing.expect(cdp.at(dl.value, "error") == null);

    const t1 = std.Io.Timestamp.now(std.testing.io, .awake);
    const dl_res = try page.evalJson("(async () => (await (await fetch('/bulk.bin')).text()).length)()");
    defer allocator.free(dl_res);
    const dl_ms = t1.durationTo(std.Io.Timestamp.now(std.testing.io, .awake)).toMilliseconds();
    try testing.expectEqualStrings("65536", dl_res);
    try testing.expect(dl_ms >= 350);

    // 4. Network.disable clears rules: global offline cleared immediately.
    var off_all = try page.client.call(
        "Network.emulateNetworkConditionsByRule",
        "{\"offline\":true,\"matchedNetworkConditions\":[]}",
        page.session,
    );
    defer off_all.deinit();
    try testing.expect(cdp.at(off_all.value, "error") == null);

    var dis = try page.client.call("Network.disable", "{}", page.session);
    defer dis.deinit();
    const after_disable = try page.evalJson("(async () => (await fetch('/data.json')).status)()");
    defer allocator.free(after_disable);
    try testing.expectEqualStrings("200", after_disable);
}

test "CDP legacy Network.emulateNetworkConditions toggles navigator.onLine and blocks fetch" {
    var gpa = LeakChecked.init;
    defer testing.expectEqual(.ok, gpa.deinit()) catch {};
    const allocator = gpa.allocator();

    const site = try Site.start(allocator);
    defer site.stop();
    var url_buf: [128]u8 = undefined;
    const root_url = try site.url(&url_buf, "/");

    var page = try CdpPage.open(allocator, root_url);
    defer page.close();

    var r = try page.client.call("Network.enable", "{}", page.session);
    r.deinit();
    r = try page.client.call("Runtime.enable", "{}", page.session);
    r.deinit();

    var off = try page.client.call(
        "Network.emulateNetworkConditions",
        "{\"offline\":true,\"latency\":0,\"downloadThroughput\":0,\"uploadThroughput\":0}",
        page.session,
    );
    defer off.deinit();
    try testing.expect(cdp.at(off.value, "error") == null);

    const offline_state = try page.evalJson(
        \\(async () => {
        \\  let failed = false;
        \\  try { await fetch('/data.json'); } catch (e) { failed = true; }
        \\  return [navigator.onLine, failed];
        \\})()
    );
    defer allocator.free(offline_state);
    try testing.expectEqualStrings("[false,true]", offline_state);

    var on = try page.client.call(
        "Network.emulateNetworkConditions",
        "{\"offline\":false,\"latency\":0,\"downloadThroughput\":-1,\"uploadThroughput\":-1}",
        page.session,
    );
    defer on.deinit();
    try testing.expect(cdp.at(on.value, "error") == null);

    const online_state = try page.evalJson(
        \\(async () => [navigator.onLine, (await fetch('/data.json')).status])()
    );
    defer allocator.free(online_state);
    try testing.expectEqualStrings("[true,200]", online_state);
}

test "MCP emulate networkConditions: presets, timeout text, Offline fetch failure, Fast 4G latency, and clear" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const site = try Site.start(h.gpa.allocator());
    defer site.stop();
    const a = h.arena.allocator();
    var buf: [128]u8 = undefined;
    const root = try a.dupe(u8, try site.url(&buf, "/"));

    var r = try h.tool("navigate_page", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"url\":\"{s}\"}}", .{root}));
    try testing.expect(!r.is_error);

    try expectResult(&h, "() => { window.__log = []; window.addEventListener('offline', () => window.__log.push('offline')); window.addEventListener('online', () => window.__log.push('online')); return navigator.onLine; }", "true");

    // Offline
    r = try h.tool("emulate", "{\"pageId\":1,\"networkConditions\":\"Offline\"}");
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings(
        "Emulation configured successfully\nEmulating network conditions: Offline\nDefault navigation timeout set to 10000 ms",
        r.text,
    );
    try expectResult(&h, "async () => { let err = false; try { await fetch('/data.json'); } catch (e) { err = true; } return [navigator.onLine, err, window.__log]; }", "[false,true,[\"offline\"]]");

    // Verify list_network_requests reports the failed offline fetch with ERR_INTERNET_DISCONNECTED.
    r = try h.tool("list_network_requests", "{\"pageId\":1}");
    try testing.expect(!r.is_error);
    try testing.expect(std.mem.indexOf(u8, r.text, "data.json [failed - net::ERR_INTERNET_DISCONNECTED]") != null);
    try testing.expect(std.mem.indexOf(u8, r.text, "Emulating network conditions: Offline\nDefault navigation timeout set to 10000 ms") != null);

    // Slow 3G -> 10x -> 100000 ms, online restored
    r = try h.tool("emulate", "{\"pageId\":1,\"networkConditions\":\"Slow 3G\"}");
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings(
        "Emulation configured successfully\nEmulating network conditions: Slow 3G\nDefault navigation timeout set to 100000 ms",
        r.text,
    );
    try expectResult(&h, "() => [navigator.onLine, window.__log]", "[true,[\"offline\",\"online\"]]");

    // Fast 3G -> 5x -> 50000 ms
    r = try h.tool("emulate", "{\"pageId\":1,\"networkConditions\":\"Fast 3G\"}");
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings(
        "Emulation configured successfully\nEmulating network conditions: Fast 3G\nDefault navigation timeout set to 50000 ms",
        r.text,
    );

    // Slow 4G -> 2.5x -> 25000 ms
    r = try h.tool("emulate", "{\"pageId\":1,\"networkConditions\":\"Slow 4G\"}");
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings(
        "Emulation configured successfully\nEmulating network conditions: Slow 4G\nDefault navigation timeout set to 25000 ms",
        r.text,
    );

    // Fast 4G -> 1x -> 10000 ms, 165 ms latency
    r = try h.tool("emulate", "{\"pageId\":1,\"networkConditions\":\"Fast 4G\"}");
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings(
        "Emulation configured successfully\nEmulating network conditions: Fast 4G\nDefault navigation timeout set to 10000 ms",
        r.text,
    );
    const t0 = std.Io.Timestamp.now(std.testing.io, .awake);
    try expectResult(&h, "async () => (await fetch('/data.json')).status", "200");
    const elapsed_ms = t0.durationTo(std.Io.Timestamp.now(std.testing.io, .awake)).toMilliseconds();
    try testing.expect(elapsed_ms >= 120);

    // Clear emulation
    r = try h.tool("emulate", "{\"pageId\":1}");
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings("Emulation configured successfully", r.text);
    r = try h.tool("list_console_messages", "{\"pageId\":1}");
    try testing.expect(std.mem.indexOf(u8, r.text, "Emulating network conditions") == null);
    try expectResult(&h, "async () => (await fetch('/data.json')).status", "200");
}
