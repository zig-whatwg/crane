//! Lane mcp1, batch 2: when a PARSED title reaches its target. A page whose
//! body streams in after its <title> (lane cdpr's /streamed.html: the head
//! and the title in the first chunk, the rest 300 ms later): from the
//! commit on, Target.getTargets names the title before
//! Page.domContentEventFired, as Chrome 157 does - Blink reports a title
//! once its element has its children (HTMLTitleElement's ChildrenChanged /
//! FinishParsingChildren -> Document::UpdateTitle), not at the end of
//! parsing.
//!
//! COMPARING with Chrome: run Chrome for Testing 157 with
//! `--headless=new --remote-debugging-port=<port> --user-data-dir=<empty dir> about:blank`
//! and this test with CRANE_CDP_TRACE_CHROME_PORT=<port>: it drives that
//! Chrome's browser target instead, and prints what it saw with
//! CRANE_CDP_TRACE_VERBOSE set - the messages from the navigation to a
//! second after the load, with each targetInfoChanged's title.

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const browser_mod = @import("browser");
const devtools = @import("devtools");
const cdp = @import("cdp_client.zig");
const replay = @import("cdpr_replay.zig");

const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });

fn verbose() bool {
    return std.c.getenv("CRANE_CDP_TRACE_VERBOSE") != null;
}

fn progress(comptime format: []const u8, args: anytype) void {
    if (!verbose()) return;
    std.debug.print("mcp1_title_timing: " ++ format ++ "\n", args);
}

/// The browser target's WebSocket path on `port` (/json/version).
fn browserPath(allocator: Allocator, port: u16) ![]u8 {
    var version = try cdp.httpGet(allocator, port, "/json/version", &.{"Host: 127.0.0.1"});
    defer version.deinit();
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, version.body, .{});
    defer parsed.deinit();
    const ws = parsed.value.object.get("webSocketDebuggerUrl").?.string;
    return allocator.dupe(u8, ws[std.mem.indexOf(u8, ws, "/devtools/").?..]);
}

const Seen = struct {
    /// Target.getTargets named the title before DOMContentLoaded.
    listed_before_dcl: bool,
    /// A Target.targetInfoChanged named it: before DOMContentLoaded, and
    /// at all up to a second after the load.
    event_before_dcl: bool,
    event_at_all: bool,
};

/// Attach to the page target, navigate it to the streamed page, and poll
/// Target.getTargets from the commit until DOMContentLoaded.
fn titleTiming(allocator: Allocator, client: *cdp.Client, url: []const u8) !Seen {
    var rec = replay.Recorder.init(allocator, client);
    defer rec.deinit();
    _ = try rec.awaitResponse(try rec.send("Target.setDiscoverTargets", "{\"discover\":true}", ""));
    const targets = try rec.result(try rec.send("Target.getTargets", "{}", ""));
    var page_id: ?[]const u8 = null;
    for (targets.object.get("targetInfos").?.array.items) |info| {
        if (std.mem.eql(u8, info.object.get("type").?.string, "page")) page_id = info.object.get("targetId").?.string;
    }
    const target_id = try allocator.dupe(u8, page_id orelse return error.NoPage);
    defer allocator.free(target_id);
    var buffer: [512]u8 = undefined;
    const attached = try rec.result(try rec.send("Target.attachToTarget", try std.fmt.bufPrint(&buffer, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{target_id}), ""));
    const session = try allocator.dupe(u8, attached.object.get("sessionId").?.string);
    defer allocator.free(session);
    _ = try rec.awaitResponse(try rec.send("Page.enable", "{}", session));
    const start = rec.log.items.len;
    _ = try rec.send("Page.navigate", try std.fmt.bufPrint(&buffer, "{{\"url\":\"{s}\"}}", .{url}), session);
    _ = try rec.awaitEvent("Page.frameNavigated", session, start, &.{});

    // The title as getTargets lists it, until DOMContentLoaded.
    var listed_at: ?usize = null;
    while (rec.eventIndex("Page.domContentEventFired", session, start, &.{}) == null) {
        const id = try rec.send("Target.getTargets", "{}", "");
        const answered = try rec.awaitResponse(id);
        const infos = cdp.at(rec.at(answered), "result.targetInfos") orelse return error.NoResult;
        for (infos.array.items) |info| {
            if (!std.mem.eql(u8, cdp.stringAt(info, "targetId") orelse "", target_id)) continue;
            if (std.mem.eql(u8, cdp.stringAt(info, "title") orelse "", "streamed")) listed_at = answered;
        }
        if (listed_at != null) break;
        std.Io.sleep(std.testing.io, .fromMilliseconds(10), .awake) catch {};
    }
    const dcl = try rec.awaitEvent("Page.domContentEventFired", session, start, &.{});
    _ = try rec.awaitEvent("Page.loadEventFired", session, start, &.{});
    // A second more of events (a title event Chrome might send late).
    _ = try rec.awaitResponse(try rec.send("Runtime.evaluate", "{\"expression\":\"new Promise(r => setTimeout(r, 1000))\",\"awaitPromise\":true}", session));
    const titled = rec.eventIndex("Target.targetInfoChanged", "", start, &.{
        .{ .path = "params.targetInfo.targetId", .equals = target_id },
        .{ .path = "params.targetInfo.title", .equals = "streamed" },
    });
    if (verbose()) {
        for (rec.log.items[start..], start..) |m, i| {
            const method = cdp.stringAt(m.value, "method") orelse continue;
            progress("{d}: {s} {s}", .{ i, method, cdp.stringAt(m.value, "params.targetInfo.title") orelse "" });
        }
        progress("getTargets named the title at message {?d}; its targetInfoChanged at {?d}; DOMContentLoaded at {d}", .{ listed_at, titled, dcl });
    }
    return .{
        .listed_before_dcl = if (listed_at) |at| at < dcl else false,
        .event_before_dcl = if (titled) |at| at < dcl else false,
        .event_at_all = titled != null,
    };
}

test "a parsed title is in Target.getTargets before DOMContentLoaded when the body streams in after it, as Chrome's" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const site = try replay.Site.start(allocator);
    defer site.stop();
    var url_buffer: [96]u8 = undefined;
    const url = try site.url(&url_buffer, "/streamed.html");

    if (std.c.getenv("CRANE_CDP_TRACE_CHROME_PORT")) |port_text| {
        const port = try std.fmt.parseInt(u16, std.mem.span(port_text), 10);
        const path = try browserPath(allocator, port);
        defer allocator.free(path);
        const client = try cdp.Client.openWebSocket(allocator, port, path, null);
        defer client.close();
        if (client.upgrade_status != 101) return error.UpgradeRefused;
        const seen = try titleTiming(allocator, client, url);
        progress("Chrome: listed before DOMContentLoaded {}, event before {}, event at all {}", .{ seen.listed_before_dcl, seen.event_before_dcl, seen.event_at_all });
        try testing.expect(seen.listed_before_dcl);
        return;
    }

    const host = try browser_mod.BrowserHost.start(allocator, .{});
    defer host.stop();
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer server.stop();
    const path = try browserPath(allocator, server.port);
    defer allocator.free(path);
    const client = try cdp.Client.openWebSocket(allocator, server.port, path, null);
    defer client.close();
    const seen = try titleTiming(allocator, client, url);
    progress("Crane: listed before DOMContentLoaded {}, event before {}, event at all {}", .{ seen.listed_before_dcl, seen.event_before_dcl, seen.event_at_all });
    try testing.expect(seen.listed_before_dcl);
}
