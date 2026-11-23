//! Chrome DevTools' own front end connected to Crane (lane cdpd1, batch 5;
//! roadmap cdp-live-dom's proof): Chrome for Testing 157 opens its bundled
//! DevTools (devtools://devtools/bundled/inspector.html?ws=<Crane>/devtools/
//! page/<id>) on a Crane page target; the Elements panel shows the page's
//! tree, stays live while page script changes it, and an edit made through
//! the panel's own DOM model (SDK.DOMModel, what the panel's attribute
//! editor calls) reaches Crane's DOM. Screenshots of the front end are
//! written at each stage.
//!
//! It needs a Chrome, so it runs only with CRANE_DEVTOOLS_CHROME_PORT=<port>
//! (Chrome for Testing 157 started with --headless=new
//! --remote-debugging-port=<port> --user-data-dir=<empty dir>) and
//! CRANE_DEVTOOLS_SHOTS=<directory>; without them it is skipped.

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const browser_mod = @import("browser");
const devtools = @import("devtools");
const cdp = @import("cdp_client.zig");

const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });

const page_url = "data:text/html,<!doctype html><title>crane-live-dom</title><body><div id=a><span>x</span></div><p id=b>crane-marker</p></body>";

/// Every text of the front end's DOM, shadow trees included (the Elements
/// tree lives in shadow roots).
const deep_text =
    \\(() => { const out = []; const walk = (n) => { if (n.shadowRoot) walk(n.shadowRoot);
    \\  for (const c of n.childNodes) { if (c.nodeType === 3) out.push(c.data); else walk(c); } };
    \\  walk(document); return out.join(' '); })()
;

fn jsonString(allocator: Allocator, s: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.append(allocator, '"');
    for (s) |c| switch (c) {
        '"' => try out.appendSlice(allocator, "\\\""),
        '\\' => try out.appendSlice(allocator, "\\\\"),
        '\n' => try out.appendSlice(allocator, "\\n"),
        else => try out.append(allocator, c),
    };
    try out.append(allocator, '"');
    return out.toOwnedSlice(allocator);
}

/// Runtime.evaluate `expression` (awaited) on `session`; its value as text.
fn evaluate(allocator: Allocator, client: *cdp.Client, session: []const u8, expression: []const u8) ![]u8 {
    const quoted = try jsonString(allocator, expression);
    defer allocator.free(quoted);
    const params = try std.fmt.allocPrint(allocator, "{{\"expression\":{s},\"awaitPromise\":true,\"returnByValue\":true}}", .{quoted});
    defer allocator.free(params);
    var got = try client.call("Runtime.evaluate", params, session);
    defer got.deinit();
    const result = got.value.object.get("result") orelse return allocator.dupe(u8, "");
    const value = result.object.get("result").?.object.get("value") orelse return allocator.dupe(u8, "");
    return switch (value) {
        .string => |s| allocator.dupe(u8, s),
        .bool => |b| allocator.dupe(u8, if (b) "true" else "false"),
        else => allocator.dupe(u8, "?"),
    };
}

/// CRANE_DEVTOOLS_VERBOSE set: progress on stderr.
fn progress(comptime format: []const u8, args: anytype) void {
    if (std.c.getenv("CRANE_DEVTOOLS_VERBOSE") == null) return;
    std.debug.print("cdpd1 frontend: " ++ format ++ "\n", args);
}

/// Wait (30 s) until the front end's text holds `needle`.
fn waitForText(allocator: Allocator, client: *cdp.Client, session: []const u8, needle: []const u8) !void {
    var tries: usize = 0;
    while (tries < 300) : (tries += 1) {
        const text = try evaluate(allocator, client, session, deep_text);
        defer allocator.free(text);
        if (std.mem.indexOf(u8, text, needle) != null) return;
        @import("platform").sleepThread(100 * std.time.ns_per_ms);
    }
    return error.FrontendNeverShowed;
}

/// Page.captureScreenshot of the front end into `<dir>/<name>.png`.
fn screenshot(allocator: Allocator, client: *cdp.Client, session: []const u8, dir: []const u8, name: []const u8) !void {
    var got = try client.call("Page.captureScreenshot", "{\"format\":\"png\"}", session);
    defer got.deinit();
    const data = got.value.object.get("result").?.object.get("data").?.string;
    const decoder = std.base64.standard.Decoder;
    const size = try decoder.calcSizeForSlice(data);
    const png = try allocator.alloc(u8, size);
    defer allocator.free(png);
    try decoder.decode(png, data);
    const path = try std.fmt.allocPrint(allocator, "{s}/{s}.png", .{ dir, name });
    defer allocator.free(path);
    const io = testing.io;
    const file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, png);
}

test "Chrome DevTools' Elements panel on a Crane page shows the tree, stays live through script mutations, and applies its own edits" {
    const port_text = std.c.getenv("CRANE_DEVTOOLS_CHROME_PORT") orelse return error.SkipZigTest;
    const shots = std.mem.span(std.c.getenv("CRANE_DEVTOOLS_SHOTS") orelse return error.SkipZigTest);
    const chrome_port = try std.fmt.parseInt(u16, std.mem.span(port_text), 10);
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    // Crane: a tab on the page, served over CDP.
    const host = try browser_mod.BrowserHost.start(allocator, .{});
    defer host.stop();
    _ = try host.createTab(.{});
    // The front end's WebSocket carries Origin: devtools://devtools, which a
    // remote end serves only when --remote-allow-origins lists it - Chrome's
    // own rule (devtools_http_handler.cc OnWebSocketRequest), so inspecting
    // a Chrome from another Chrome's DevTools needs the same flag.
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host, .allowed_origins = &.{"devtools://devtools"} });
    defer server.stop();
    var list = try cdp.httpGet(allocator, server.port, "/json/list", &.{"Host: 127.0.0.1"});
    defer list.deinit();
    const targets = try std.json.parseFromSlice(std.json.Value, allocator, list.body, .{});
    defer targets.deinit();
    const page_id = targets.value.array.items[0].object.get("id").?.string;
    const crane_path = try std.fmt.allocPrint(allocator, "/devtools/page/{s}", .{page_id});
    defer allocator.free(crane_path);
    progress("Crane page target {s} on port {d}", .{ crane_path, server.port });
    const crane = try cdp.Client.openWebSocket(allocator, server.port, crane_path, null);
    defer crane.close();
    var nav_params: std.ArrayList(u8) = .empty;
    defer nav_params.deinit(allocator);
    const quoted_url = try jsonString(allocator, page_url);
    defer allocator.free(quoted_url);
    try nav_params.print(allocator, "{{\"url\":{s}}}", .{quoted_url});
    var enabled = try crane.call("Page.enable", "{}", "");
    enabled.deinit();
    var nav = try crane.call("Page.navigate", nav_params.items, "");
    nav.deinit();
    var loaded = try crane.waitEvent("Page.loadEventFired");
    loaded.deinit();
    progress("Crane loaded the page", .{});

    // Chrome: its browser target, a tab with the bundled front end on Crane.
    var version = try cdp.httpGet(allocator, chrome_port, "/json/version", &.{"Host: 127.0.0.1"});
    defer version.deinit();
    const version_json = try std.json.parseFromSlice(std.json.Value, allocator, version.body, .{});
    defer version_json.deinit();
    const browser_ws = version_json.value.object.get("webSocketDebuggerUrl").?.string;
    const browser_path = browser_ws[std.mem.indexOf(u8, browser_ws, "/devtools/").?..];
    const chrome = try cdp.Client.openWebSocket(allocator, chrome_port, browser_path, null);
    defer chrome.close();
    if (chrome.upgrade_status != 101) return error.UpgradeRefused;
    progress("Chrome browser target {s}", .{browser_path});
    const frontend = try std.fmt.allocPrint(allocator, "devtools://devtools/bundled/inspector.html?ws=127.0.0.1:{d}/devtools/page/{s}", .{ server.port, page_id });
    defer allocator.free(frontend);
    const create = try std.fmt.allocPrint(allocator, "{{\"url\":\"{s}\"}}", .{frontend});
    defer allocator.free(create);
    var created = try chrome.call("Target.createTarget", create, "");
    defer created.deinit();
    const frontend_target = created.value.object.get("result").?.object.get("targetId").?.string;
    const attach = try std.fmt.allocPrint(allocator, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{frontend_target});
    defer allocator.free(attach);
    var attached = try chrome.call("Target.attachToTarget", attach, "");
    defer attached.deinit();
    const session = attached.value.object.get("result").?.object.get("sessionId").?.string;
    var shown = try chrome.call("Emulation.setDeviceMetricsOverride", "{\"width\":1280,\"height\":800,\"deviceScaleFactor\":1,\"mobile\":false}", session);
    shown.deinit();

    // 1. The Elements panel shows Crane's tree.
    progress("front end attached ({s}); waiting for the tree", .{session});
    try waitForText(allocator, chrome, session, "crane-marker");
    progress("tree shown", .{});
    try screenshot(allocator, chrome, session, shots, "1-elements");

    // 2. Page script changes the tree; the panel follows (childNodeInserted,
    // attributeModified, characterDataModified).
    const mutated = try evaluate(allocator, crane, "", "const p = document.createElement('p'); p.id = 'crane-live'; p.textContent = 'live-text'; document.body.append(p); document.getElementById('a').setAttribute('data-live', 'yes'); document.getElementById('b').firstChild.data = 'crane-marker-changed'; 'ok'");
    allocator.free(mutated);
    try waitForText(allocator, chrome, session, "live-text");
    try waitForText(allocator, chrome, session, "data-live");
    try waitForText(allocator, chrome, session, "crane-marker-changed");
    try screenshot(allocator, chrome, session, shots, "2-live");

    // 3. An edit through the panel's DOM model reaches Crane's DOM.
    const edited = try evaluate(allocator, chrome, session,
        \\(async () => { const SDK = await import('./core/sdk/sdk.js');
        \\  const target = SDK.TargetManager.TargetManager.instance().primaryPageTarget();
        \\  const model = target.model(SDK.DOMModel.DOMModel); const doc = await model.requestDocument();
        \\  const id = await model.querySelector(doc.id, '#crane-live');
        \\  await model.nodeForId(id).setAttributeValuePromise('title', 'from-devtools'); return 'edited'; })()
    );
    defer allocator.free(edited);
    try testing.expectEqualStrings("edited", edited);
    const seen = try evaluate(allocator, crane, "", "document.getElementById('crane-live').title");
    defer allocator.free(seen);
    try testing.expectEqualStrings("from-devtools", seen);
    try waitForText(allocator, chrome, session, "from-devtools");
    try screenshot(allocator, chrome, session, shots, "3-edited");
}
